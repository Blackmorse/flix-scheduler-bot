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
            case Some(token) => 
                match TelegramApi.getLatestUpdateId(token, None)  {
                    case Ok(updateId) => println("Latest update ID: ${updateId}")
                    case Err(e) => println("Error fetching latest update ID: ${e}")
                }
            case None => println("Error: TELEGRAM_BOT_TOKEN environment variable is not set.")
        } 
    } with TelegramApi.runWithHttpsHandler
