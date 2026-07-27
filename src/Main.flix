use Sys.Env
use Net.Https

def main(): Unit \ { Env, IO, Https }  =
    run {
        match Env.getVar("TELEGRAM_BOT_TOKEN") {
            case Some(token) => match runLoop(token, None) {
                    case Ok(updateId) => println("Latest update ID: ${updateId}")
                    case Err(e) => println("Error fetching latest update ID: ${e}")
                }
            case None => println("Error: TELEGRAM_BOT_TOKEN environment variable is not set.")
        } 
    } with TelegramApi.runWithHttpsHandler


@Tailrec
def runLoop(token: String, offset: Option[Int64]): Result[TelegramApi.Error, Int64] \ { IO, TelegramApi } = 
    let updates = match TelegramApi.fetchUpdates(token, offset) {
        case Ok(updates) => updates
        case Err(_) => Nil
    };
    let nextUpdate = updates |> List.map(update -> match update {
        case TelegramApi.TelegramUpdate.TextMessage({updateId | _}) => updateId
        case TelegramApi.TelegramUpdate.OtherUpdate(updateId) => updateId
    }) |> List.maximum |> Option.map(id -> id + 1i64);
    println("Next update ID: ${nextUpdate}");
    runLoop(token, nextUpdate)
