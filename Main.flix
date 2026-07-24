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
                match TelegramApi.getLatestUpdateId(token)  {
                    case Ok(updateId) => println("Latest update ID: ${updateId}")
                    case Err(e) => println("Error fetching latest update ID: ${e}")
                }
            case None => println("Error: TELEGRAM_BOT_TOKEN environment variable is not set.")
        } 
    } with handler TelegramApi {
        def getLatestUpdateId(token, resume) = 
            let update = getLatestUpdateId(token);
            resume(update)
    }

// TODO: 
// 1. Create enum with an errors
// 2. Errors might be of different nature - like network, request error(4xx, 5xx etc etc)
// 3. Test all of that failing scenarios by providing Https handler for tests
def getLatestUpdateId(token: String): Result[JsonError, Int64] \ { Https } =
    match Https.get("https://api.telegram.org/${token}/getUpdates") {
       case Ok(response) => 
          let body = HttpResponse.body(response);
          match extractUpdateIdsFromHttpResponseBody(body) {
                case Ok(ids) => 
                    let max = List.maximum(ids);
                    match max {
                        case Some(id) => Ok(id)
                        case None => Err(JsonError.Decode(JsonPath.empty(), DecodeErrorKind.TypeMismatch("no updates found")))
                    }
                case Err(e) => Err(e)
          }
        case Err(e) => Err(JsonError.Decode(JsonPath.empty(), DecodeErrorKind.TypeMismatch("HTTP request failed: ${e}")))
    }


eff TelegramApi {
    def getLatestUpdateId(token: String): Result[JsonError, Int64]
} 

def extractUpdateIdsFromHttpResponseBody(body: String): Result[JsonError, List[Int64]] =
    forM (
        json <- parse(body);
        result <- FromJson.getAtKey("result", json);
        ids <- match result {
            case JArray(v) => Result.traverse(extractId, Vector.toList(v))
            case _ => Err(JsonError.Decode(JsonPath.empty(), DecodeErrorKind.TypeMismatch("expected array")))
        }
    ) yield ids

def extractId(j: Json): Result[JsonError, Int64] =
  match j {
     case JObject(_) => FromJson.decodeAtKey("update_id", j)
     case _          => Err(JsonError.Decode(JsonPath.empty(),            
                                 DecodeErrorKind.TypeMismatch("expected object")))
 }
