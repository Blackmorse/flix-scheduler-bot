use Sys.Env
use Util.Json.JArray
use Util.Json.decode
use Util.Json.parse
use Util.Json.Json
use Util.Json.FromJson
use Util.Json.JsonPath
use Util.Json.JObject
use Util.Json.JsonError.JsonError
use Util.Json.JsonError.DecodeErrorKind
use Net.Https
use Net.HttpResponse

def main(): Unit \ { Env, IO, Https }  =
    run {
        match Env.getVar("TELEGRAM_BOT_TOKEN") {
            case Some(token) => match runLoop(token, None) {
                // match TelegramApi.getLatestUpdateId(token, None)  {
                    case Ok(updateId) => println("Latest update ID: ${updateId}")
                    case Err(e) => println("Error fetching latest update ID: ${e}")
                }
            case None => println("Error: TELEGRAM_BOT_TOKEN environment variable is not set.")
        } 
    } with TelegramApi.runWithHttpsHandler

@Tailrec
def runLoop(token: String, offset: Option[Int64]): Result[TelegramApi.Error, Int64] \ { IO, TelegramApi } = 
    let id = match TelegramApi.getLatestUpdateId(token, offset) {
        case Ok(id) => Some(id + 1i64)
        case Err(_) => offset
    };
    println("Latest update ID: ${id}");
    runLoop(token, id)
