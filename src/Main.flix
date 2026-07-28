use Sys.Env
use Net.Https

def main(): Unit \ { Env, IO, Https  }  = {
    let _token = match Env.getVar("TELEGRAM_BOT_TOKEN") {
        case Some(token) =>
            run {
                let _ = runLoop(None);
                println("asd")
            } with TelegramApi.runWithHttpsHandler
              with handler TelegramApi.TelegramBotToken {
                def getToken(resume) = resume(token)
            }
        case None => println("Error: TELEGRAM_BOT_TOKEN environment variable is not set.")
      };
      println("Done")
    }

@Tailrec
def runLoop(offset: Option[Int64]): Result[TelegramApi.Error, Int64] \ { IO, TelegramApi } = 
    let updates = match TelegramApi.fetchUpdates(offset) {
        case Ok(updates) => updates
        case Err(_) => Nil
    };
    let nextUpdate = updates |> List.map(update -> match update {
        case TelegramApi.TelegramUpdate.TextMessage({updateId | _}) => updateId
        case TelegramApi.TelegramUpdate.OtherUpdate(updateId) => updateId
    }) |> List.maximum |> Option.map(id -> id + 1i64);
    println("Next update ID: ${nextUpdate}");
    runLoop(nextUpdate)
