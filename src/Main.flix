use Commands.CommandParseError
use State.{StateWrite, StateRead}
use Storage.{StorageWrite, StorageRead}
use TelegramApi.Models.{runWithToken, TelegramBotToken, TelegramUpdate}
use TelegramApi.Receiver.Listeners.{TelegramUpdatesListener, runWithChannelLongPolling}
use Sys.Env
use Net.Https
use Commands.{FromString, Command}
use Storage.Storage


def main(): Unit \ { Env, IO, Chan, NonDet }  = {
    region rc {
        match Env.getVar("TELEGRAM_BOT_TOKEN") {
            case Some(token) =>
                run {
                    let (sender, receiver) = Channel.buffered(100);
                    spawn listen(sender, token) @ rc;
                    handleUpdatesPipeline(receiver)
            } with runWithToken(token)
              with Https.runWithIO
              // TODO handle with Storage and State read/write effects
              with State.runWithReadState
              with State.runWithWriteState
              with State.runWithInMemoryState(rc)
              with Storage.runWithReadStorage
              with Storage.runWithWriteStorage
              with Storage.runWithInMemoryStorage("First category" :: "Second Category" :: Nil, rc)
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
def handleUpdatesPipeline(rx: Receiver[TelegramUpdate]): Unit \ { IO, NonDet, Https, TelegramBotToken, Chan, StorageRead, StateRead, StorageWrite, StateWrite } = 
    match Channel.recv(rx) {
        case TelegramUpdate.TextMessage({chatId, message = text | _}) => 
            let result = forM (
                 command    <- FromString.fromString(text) |> Result.mapErr(e -> Executor.ExecuteError.ParseError(e));
                 plan       <- Planner.createPlan(chatId, command);
                 executions <- List.traverse(action -> Executor.Executable.execute(action), plan)
            ) yield executions;
            match result {
                case Ok(_) => handleUpdatesPipeline(rx)
                case Err(e) =>
                    println("Error executing plan: ${e}");
                    handleUpdatesPipeline(rx)
            }
        case _ => handleUpdatesPipeline(rx)
    }
