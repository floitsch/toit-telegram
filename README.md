# Telegram

A minimal Telegram client in Toit.

This library is a work in progress. If you are missing a feature, please open an issue.

Patches are welcome.

## Creating a new bot

Create the `/newbot` command to create a new bot. '@BotFather' will ask
you for a name and username, then give you an authentication token.

See [the official instructions](https://core.telegram.org/bots/features#botfather).

## Usage

See the [examples](examples) folder for an example.

```toit
import telegram show *

main:
  // Typically you want to get the token from the environment or
  // from a separate file to keep the secrets out of the source code.
  // See the examples folder.
  client := Client --token="<your token>"

  client.listen: | update/Update |
    if update is UpdateMessage:
      message := (update as UpdateMessage).message
      print "Got message: $message"
      if message.text == "/start":
        // It's generally a good idea to reply within the block.
        // This requires fewer connections to the server.
        client.send_message --chat_id=message.chat.id "Hello World"
    else:
      print "Got update: $update"
```

## Features and bugs
Please file feature requests and bugs at the [issue tracker](https://github.com/floitsch/toit-discord/issues).
