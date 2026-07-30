use TelegramApi.Models.TelegramBotToken;
use TelegramApi.Handler.runWithHttpsMessageSender;
use TelegramApi.Receiver.runWithLongPollingLoop;
use TelegramApi.Models.{TelegramUpdate, OutgoingMessage}
use TelegramApi.Handler.{UserMessageHandler, sendMessage}
use TelegramApi.Receiver.TelegramUpdatesListener
use Sys.Env
use Net.{Https, HttpRequest}

def main(): Unit \ { Env, IO, Https }  = {
    match Env.getVar("TELEGRAM_BOT_TOKEN") {
        case Some(token) =>
            run {
                let _ = TelegramUpdatesListener.listenToUpdates();
                ()
            } with runWithLongPollingLoop
              with handler UserMessageHandler {
                  def handleMessage(message, resume) = match message {
                      case TelegramUpdate.TextMessage({chatId, message = text | _}) => 
                          let _ = OutgoingMessage.TextMessage({chatId = chatId, text = "You said: ${text}"}) 
                            |> sendMessage;
                          // ignoring errors right now
                          resume(())
                      case _ => resume(())
                  }
              }
              with handler TelegramBotToken {
                def getToken(resume) = resume(token)
            }
        case None => println("Error: TELEGRAM_BOT_TOKEN environment variable is not set.")
      }
    }
