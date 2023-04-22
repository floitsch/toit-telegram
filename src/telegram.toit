// Copyright (C) 2023 Florian Loitsch.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

// Using a local telegram-bot-api server:
//   https://github.com/tdlib/telegram-bot-api

import encoding.json
import certificate_roots
import log
import net
import tls
import http
import monitor
import reader show BufferedReader
import .model
export *

/**
Token to allow access to the telegram service.
Use BotFather to create tokens: https://core.telegram.org/bots#6-botfather
*/
HOST_ ::= "api.telegram.org"
PORT_ ::= 443
CERTIFICATE_ ::= certificate_roots.GO_DADDY_ROOT_CERTIFICATE_AUTHORITY_G2

class Client:
  network_/net.Interface? := null
  client1_/http.Client? := null
  // Due to long polling the first client might be busy.
  // In that case we use the second client.
  // We will never use the second client if a message is sent in the
  // block that is called for updates.
  client2_/http.Client? := null
  closed_/bool := false
  token_/string
  handling_updates_/bool := false
  clients_in_use_/int := 0  // Bit mask: 1 = client1, 2 = client2.
  clients_semaphore/monitor.Semaphore := monitor.Semaphore
  logger_/log.Logger

  constructor --token/string --logger/log.Logger=log.default:
    logger_ = logger.with_name "telegram"
    token_ = token
    network_ = net.open
    client1_ = http.Client.tls network_
      --root_certificates=[CERTIFICATE_]
    clients_semaphore.up

  connect_client2_ -> none:
    if not client2_:
      client2_ = http.Client.tls network_
        --root_certificates=[CERTIFICATE_]
      clients_semaphore.up

  /**
  Closes the connection.
  If $hard is not set, and if we are in the middle of handling updates,
    waits until the current update (but not all pending updates) is handled.
    Then acknowledges the last received update, before closing down.
  If $hard is set, closes the connection immediately.
  */
  close --hard/bool=false -> none:
    closed_ = true
    if handling_updates_ and not hard:
      logger_.info "doing a soft close"
      return
    logger_.info "closing"
    if client1_:
      client1_.close
      client1_ = null
    if client2_:
      client2_.close
      client2_ = null
    if network_:
      network_.close
      network_ = null

  /**
  Listens for updates from the Telegram server.
  The $block is called with an $Update object for each received update.
  The $block must return as soon as possible, to allow the client to
    receive more updates.
  If $ignore_old is set, then the client will drop all updates
    that were received before the client was started.
  */
  listen --ignore_old/bool=false [block]:
    logger_.info "listening"
    last_received_update_id/int? := null
    is_first_getupdate/bool := true
    while not closed_:
      exception := catch --trace:
        opt := {
          "timeout" : 600,
        }
        if last_received_update_id:
          opt["offset"] = last_received_update_id + 1
        else if ignore_old and is_first_getupdate:
          opt["offset"] = -1
          opt["limit"] = 1
          opt["timeout"] = 0
        logger_.debug "requesting updates"
        updates := request_ "getUpdates" opt
        is_first_getupdate = false
        handling_updates_ = true
        try:
          for i := 0; i < updates.size; i++:
            if closed_: break
            last_received_update_id = updates[i]["update_id"]
            if ignore_old and (opt.get "offset") == -1:
              logger_.debug "ignored old updates"
              // We just requested one update, so we can ignore it.
              continue
            update := Update.from_json updates[i]
            block.call update
        finally:
          handling_updates_ = false
      // Acknowledge the last received message.
      if closed_ and not exception and last_received_update_id:
        request_ "getUpdates" {
          "offset": last_received_update_id + 1,
          "limit": 1,
          "timeout": 0,
        }
      if exception and not closed_:
        // If we are not closed, then we should try again.
        // Otherwise we just close the connection.
        logger_.error "error" --tags={"exception": exception}
        sleep --ms=5_000
    close

  /**
  Returns the user object of the bot.

  This is a simple way of checking if the token is valid.
  */
  get_me -> User:
    response := request_ "getMe" {:}
    return User.from_json response

  /**
  Sends a message to the given chat.
  */
  send_message text/string --chat_id/int:
    logger_.debug "sending message" --tags={"chat_id": chat_id, "text": text}
    return request_ "sendMessage" {
      "chat_id": chat_id,
      "text": text,
    }

  request_ method/string opt/Map -> any:
    path := "/bot$token_/$method"
    if clients_in_use_ & 1 != 0:
      // Client1 is busy.
      // Make sure we have client2 connected.
      connect_client2_

    // Wait until at least one client is free.
    clients_semaphore.down

    client/http.Client := ?
    client_bit/int := ?
    if clients_in_use_ & 1 == 0:
      // Client1 is free.
      client_bit = 1
      client = client1_
    else:
      // Client2 is free.
      client_bit = 2
      client = client2_

    clients_in_use_ |= client_bit

    try:
      response := client.post_json --host=HOST_ --path=path opt
      decoded := json.decode_stream response.body
      if not decoded["ok"]:
        throw "Error: $decoded["description"]"
      return decoded["result"]
    finally:
      clients_in_use_ &= ~client_bit
      clients_semaphore.up
    unreachable
