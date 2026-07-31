use TelegramApi.Handler.runWithHttpsMessageSender;
use TelegramApi.Receiver.runWithLongPollingLoop;
use TelegramApi.Models.{runWithToken, TelegramBotToken}
use TelegramApi.Models.{TelegramUpdate, OutgoingMessage}
use TelegramApi.Handler.{UserMessageHandler, sendMessage}
use TelegramApi.Receiver.TelegramUpdatesListener
use Sys.Env
use Net.{Https, HttpRequest}

def main(): Unit \ { Env, IO, Https }  = {
    match Env.getVar("TELEGRAM_BOT_TOKEN") {
        case Some(token) =>
          region rc {
              run {
                  let _ = TelegramUpdatesListener.listenToUpdates();
                  ()
              } with runWithLongPollingLoop(rc, handle(token))
                with runWithToken(token)
              }
        case None => println("Error: TELEGRAM_BOT_TOKEN environment variable is not set.")
      }
    }

    def handle(token: String, message: TelegramUpdate): Unit \ { IO } = run {
        match message {
            case TelegramUpdate.TextMessage({chatId, message = text | _}) => 
                let _ = OutgoingMessage.TextMessage({chatId = chatId, text = "You said: ${text}"}) 
                    |> sendMessage;
                    // ignoring errors right now
                    ()
              case _ => ()
          }
    } with runWithToken(token)
      with Https.runWithIO
