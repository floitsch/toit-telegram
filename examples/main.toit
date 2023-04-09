// Copyright (C) 2023 Florian Loitsch.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import telegram show *
import host.os
import monitor

main:
  token := os.env.get "TELEGRAM_TOKEN"
  if not token or token == "":
    print "Please set the TELEGRAM_TOKEN environment variable."
    return

  main --token=token

mentions_ message/Message username/string:
  if not message.entities: return false
  message.entities.do: | entity/MessageEntity |
    if entity.type == MessageEntity.TYPE_MENTION and
        // We can't use entity.offset and entity.length because
        // Toit uses UTF-8 and Telegram uses UTF-16.
        // TODO(florian): convert the offset and length to UTF-8.
        message.text.contains "@$username":
      return true
  return false

/**
When developing for the ESP32 a good practice is to have
  a different file (say 'esp32.toit') that just calls this main.
Check in an 'esp32-example.toit' file, but don't check in the 'esp32.toit'
  file that contains the actual credentials. It should be '.gitignore'd.

```
import .main as real_main

TOKEN ::= "YOUR TOKEN"

main:
  real_main.main --token=TOKEN
```
*/
main --token/string:
  client := Client --token=token
  my_username := client.get_me.username

  client.listen: | update/Update? |
    if update is UpdateMessage:
      print "Got message: $update"
      message := (update as UpdateMessage).message
      if message.chat and message.chat.type == Chat.TYPE_PRIVATE:
        client.send_message --chat_id=message.chat.id "Of course!"
      if mentions_ message my_username:
        client.send_message --chat_id=message.chat.id "Understood"
