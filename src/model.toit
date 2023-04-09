// Copyright (C) 2023 Florian Loitsch.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

/**
An Update by the Telegram server.
*/
abstract class Update:
  static TYPE_MESSAGE ::= "message"
  static TYPE_MESSAGE_EDITED ::= "edited_message"
  static TYPE_CHANNEL_POST ::= "channel_post"

  /**
  The type of this update.
  Can be $TYPE_MESSAGE, $TYPE_MESSAGE_EDITED, $TYPE_CHANNEL_POST, or
    any other type that Telegram sends. All other types are currently
    returned in $UpdateOther.
  */
  type/string

  constructor.from_subclass_ json/Map:
    type = "unknown"
    json.do: | key _ |
      if key != "update_id":
        type = key

  constructor.from_json json/Map:
    if json.contains "message":
      return UpdateMessage.from_json json
    if json.contains "edited_message":
      return UpdateMessageEdited.from_json json
    if json.contains "channel_post":
      return UpdateChannelPost.from_json json
    return UpdateOther.from_json json

  stringify -> string:
    return "Update"

/** A new incoming message of any kind. */
class UpdateMessage extends Update:
  /** The message that was sent. */
  message/Message

  constructor.from_json json/Map:
    message = Message.from_json json["message"]
    super.from_subclass_ json

  stringify -> string:
    return "UpdateMessage: $message"

/** A message was updated. */
class UpdateMessageEdited extends Update:
  /**
  New version of a message that is known to the bot and was edited.
  */
  message/Message

  constructor.from_json json/Map:
    message = Message.from_json json["edited_message"]
    super.from_subclass_ json

  stringify -> string:
    return "UpdateMessageEdited: $message"

/** A new incoming channel post of any kind. */
class UpdateChannelPost extends Update:
  /** The message that was sent. */
  message/Message

  constructor.from_json json/Map:
    message = Message.from_json json["channel_post"]
    super.from_subclass_ json

  stringify -> string:
    return "UpdateChannelPost: $message"

/**
An unknown update.
Used for updates that are not yet implemented.
*/
class UpdateOther extends Update:
  /** The raw json data. */
  json/Map

  constructor.from_json json/Map:
    this.json = json
    super.from_subclass_ json

/**
A Telegram user or bot.
*/
class User:
  /** The unique identifier for this user or bot. */
  id/int
  /** Whether this user is a bot. */
  is_bot/bool
  /** The first name of this user or bot. */
  first_name/string
  /** The last name of this user or bot. */
  last_name/string?
  /** The username of this user or bot. */
  username/string?

  constructor.from_json json/Map:
    id = json["id"]
    is_bot = json["is_bot"]
    first_name = json["first_name"]
    last_name = json.get "last_name"
    username = json.get "username"

/** A Telegram chat. */
class Chat:
  static TYPE_PRIVATE ::= "private"
  static TYPE_GROUP ::= "group"
  static TYPE_SUPERGROUP ::= "supergroup"
  static TYPE_CHANNEL ::= "channel"

  /** The unique identifier for this chat. */
  id/int

  /**
  The type of this chat.
  One of $TYPE_PRIVATE, $TYPE_GROUP, $TYPE_SUPERGROUP, or $TYPE_CHANNEL.
  */
  type/string

  /**
  The title of this chat.
  Only present if this chat is a group, supergroup, or channel.
  */
  title/string?

  /**
  The username of this chat.
  For private chats, supergroups and channels if available.
  */
  username/string?

  /** The first name of the other party in a private chat. */
  first_name/string?

  /** The last name of the other party in a private chat. */
  last_name/string?

  /** Whether this supergroup chat is a forum (has topics enabled). */
  is_forum/bool?

  /**
  The list of all active chat usernames.
  For private chats, supergroups and channels.
  A list of strings.
  */
  active_usernames/List?

  /** The description of this chat. */
  description/string?

  constructor.from_json json/Map:
    id = json["id"]
    type = json["type"]
    title = json.get "title"
    username = json.get "username"
    first_name = json.get "first_name"
    last_name = json.get "last_name"
    is_forum = json.get "is_forum"
    active_usernames = json.get "active_usernames"
    description = json.get "description"

/**
A Telegram message.
*/
class Message:
  /** The unique identifier for this message. */
  id/int
  /**
  The sender of this message.
  */
  from/User?
  /** The chat this message belongs to. */
  chat/Chat?
  /** The date this message was sent. */
  date_value/int
  /**
  The text of this message.
  Only present if this message is a text message.
  */
  text/string?

  /** Special entities like usernames, URLs, etc. that appear in the text. */
  entities/List?

  constructor.from_json json/Map:
    id = json["message_id"]
    from_entry := json.get "from"
    if from_entry:
      from = User.from_json(json["from"])
    else:
      from = null
    chat_entry := json.get "chat"
    if chat_entry:
      chat = Chat.from_json(json["chat"])
    else:
      chat = null
    date_value = json["date"]
    text = json.get "text"
    entities_entry := json.get "entities"
    if entities_entry:
      entities = entities_entry.map: MessageEntity.from_json it
    else:
      entities = null

  date -> Time:
    return Time.epoch --s=date_value

  stringify -> string:
    if not text: return "Non-text message"

    name/string := from.first_name
    if from.last_name:
      name = "$name $from.last_name"
    return "Message: $name: $text"

/**
A special entity in a text message.

For example, hashtags, usernames, URLs, etc.
*/
class MessageEntity:
  static TYPE_MENTION ::= "mention"
  static TYPE_HASHTAG ::= "hashtag"
  static TYPE_CASHTAG ::= "cashtag"
  static TYPE_BOT_COMMAND ::= "bot_command"
  static TYPE_URL ::= "url"
  static TYPE_EMAIL ::= "email"
  static TYPE_PHONE_NUMBER ::= "phone_number"
  static TYPE_BOLD ::= "bold"
  static TYPE_ITALIC ::= "italic"
  static TYPE_UNDERLINE ::= "underline"
  static TYPE_STRIKETHROUGH ::= "strikethrough"
  static TYPE_SPOILER ::= "spoiler"
  static TYPE_CODE ::= "code"
  static TYPE_PRE ::= "pre"
  static TYPE_TEXT_LINK ::= "text_link"
  static TYPE_TEXT_MENTION ::= "text_mention"
  static TYPE_CUSTOM_EMOJI ::= "custom_emoji"
  static TYPE_UNKNOTN ::= "unknown"  // In case Telegram adds new types.

  /**
  The type of this entity.
  See $TYPE_MENTION and similar constants.
  */
  type/string

  /** The offset in UTF-16 code units to the start of the entity. */
  offset/int

  /** The length of the entity in UTF-16 code units. */
  length/int

  /** The URL that will be opened after the user taps on the text. */
  url/string?

  /**
  The mentioned user.
  Only available for $TYPE_TEXT_MENTION, where the user has no username.
  */
  user/User?

  /** The programming language of the entity text. */
  language/string?

  /** The unique identifier of the custom emoji. */
  custom_emoji_id/string?

  constructor.from_json json/Map:
    type = json["type"]
    offset = json["offset"]
    length = json["length"]
    url = json.get "url"
    user_entry := json.get "user"
    if user_entry:
      user = User.from_json(user_entry)
    else:
      user = null
    language = json.get "language"
    custom_emoji_id = json.get "custom_emoji_id"

