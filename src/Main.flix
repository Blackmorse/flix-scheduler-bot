use TelegramApi.Models.{runWithToken, TelegramBotToken, TelegramUpdate, OutgoingMessage}
use TelegramApi.Handler.sendMessage
use TelegramApi.Receiver.Listeners.{TelegramUpdatesListener, runWithChannelLongPolling}
use Sys.Env
use Net.Https
use Commands.FromString
use Storage.Storage


def main(): Unit \ { Env, IO, Chan, NonDet }  = {
    region rc {
        match Env.getVar("TELEGRAM_BOT_TOKEN") {
            case Some(token) =>
                run {
                    let (sender, receiver) = Channel.buffered(100);
                    spawn listen(sender, token) @ rc;
                    handleUpdates(receiver)
            } with runWithToken(token)
              with Https.runWithIO
              with runWithInMemoryStorage(rc)
            case None => println("Error: TELEGRAM_BOT_TOKEN environment variable is not set.")
            }
        }
    }

def listen(sender: Sender[TelegramUpdate], token: String): Unit \ { IO + Chan } = run {
        let _ = TelegramUpdatesListener.listenToUpdates();
        ()
    } with runWithChannelLongPolling(sender)
      with runWithToken(token)
      with Https.runWithIO

@Tailrec
def handleUpdates(rx: Receiver[TelegramUpdate]): Unit \ { Chan, Https, TelegramBotToken, NonDet, Storage } =
   match Channel.recv(rx) {
        case TelegramUpdate.TextMessage({chatId, message = text | _}) =>
            let command = FromString.fromString(text); 
            match command {
                case Some(Commands.Command.AddCategory(category)) =>
                    let _ = Storage.addCategory(category);
                    let _ = OutgoingMessage.TextMessage({chatId = chatId, text = "Category added: ${category}"})
                        |> sendMessage; ()
                case Some(Commands.Command.ListCategories) =>
                    let categories = Storage.listCategories();
                    let formatted = List.map(c -> "🔹 ${c}", categories) |> List.join("\n");
                    let _ = OutgoingMessage.TextMessage({chatId = chatId, text = "📂 Categories:\n${formatted}"})
                        |> sendMessage; ()
                case _ => 
                    let _ = OutgoingMessage.TextMessage({chatId = chatId, text = "Unknown command."})
                        |> sendMessage; ()
            };
            handleUpdates(rx)
        case _ => handleUpdates(rx)
   }

