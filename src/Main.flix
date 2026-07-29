use TelegramApi.OutgoingMessage
use TelegramApi.TelegramUpdate
use TelegramApi.UserMessageHandler
use TelegramApi.TelegramBotToken
use TelegramApi.TelegramMessageSender
use Sys.Env
use Net.{Https, HttpRequest}

def main(): Unit \ { Env, IO, Https }  = {
    match Env.getVar("TELEGRAM_BOT_TOKEN") {
        case Some(token) =>
            run {
                let _ = TelegramApi.runLoop(None);
                ()
            } with TelegramApi.runWithHttpsHandler
              with handler UserMessageHandler {
                  def handleMessage(message, resume) = match message {
                      case TelegramUpdate.TextMessage({chatId, message = text | _}) => 
                          let _ = OutgoingMessage.TextMessage({chatId = chatId, text = "You said: ${text}"}) 
                            |> TelegramMessageSender.sendMessage;
                          // ignoring errors right now
                          resume(())
                      case _ => resume(())
                  }
              }
              with TelegramApi.runWithHttpsMessageSender
              with handler TelegramApi.TelegramBotToken {
                def getToken(resume) = resume(token)
            }
        case None => println("Error: TELEGRAM_BOT_TOKEN environment variable is not set.")
      }
    }
