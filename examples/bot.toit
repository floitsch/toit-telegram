import telegram show *

bot := Client --token="<your token>"

main:
  chat_id=message.chat.id
  if update is UpdateMessage:
    message:= (update as UpdateMessage).message
    print "Got message: $message"
    if message.text == "/start":
      bot.send_message chat_id "Check out https://www.toit.io/"
      bot.send_message chat_id "Check out https://www.toit.io/" --disable_web_page_preview=true
    else:
      print "Got update: $update"
