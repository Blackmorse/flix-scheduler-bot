
mod TelegramApi {
    use Util.Json.{parse, JsonError, FromJson, JString, JBool, JArray, JsonError, JsonPath}
    use Util.Json.JsonError.DecodeErrorKind
    use Util.Json.JsonPath.JsonStep
    use Util.Json
    use Net.{Https, HttpRequest, HttpResponse}
    use JsonExt.getAsArray

    pub eff TelegramApi {
        def fetchUpdates(token: String, offset: Option[Int64]): Result[Error, List[TelegramUpdate]]
    }

    pub def runWithHttpsHandler(f: Unit -> a \ ef): a \ (ef - TelegramApi) + Https = 
        run {
            f()
        } with handler TelegramApi {
            def fetchUpdates(token, offset, resume) = 
                let updates = getUpdates(token, offset);
                resume(updates)
        }

    pub enum TelegramUpdate {
        case TextMessage({updateId = Int64, message = String})
        case OtherUpdate(Int64)
    }
    
    pub enum Error with Eq, ToString {
        case NetworkError(IoError),
        case NoUpdatesFound,
        case UnexpectedResponse(JsonError),
        case ErrorResponse(String)
    }

    instance FromJson[TelegramUpdate] {
        pub def fromJson(j: Json): Result[JsonError, TelegramUpdate] = 
            forM (
                updateId <- JsonExt.getAsInt64("update_id", j);
                message  <- JsonExt.getAsStringFromPath(JsonPath(JsonStep.Key("message") :: JsonStep.Key("text") :: Nil), j)
                ) yield TelegramUpdate.TextMessage({updateId = updateId, message = message})
    }

    def getUpdates(token: String, offset: Option[Int64]): Result[Error, List[TelegramUpdate]] \ Https = 
        let offsetSuffix = match offset {
            case Some(o) => "&offset=${o}"
            case None => ""
        };
        let url = "https://api.telegram.org/${token}/getUpdates?timeout=30${offsetSuffix}";
        match Https.send(HttpRequest.get(url)) {
            case Ok(response) => match HttpResponse.body(response) |> parse {
                case Ok(json) => 
                    forM (
                        _       <- checkOkField(json);
                        results <- JsonExt.getAsArray("result", json) |> Result.map(Vector.toList) |> Result.mapErr(Error.UnexpectedResponse);
                        list    <- Result.traverse(FromJson.fromJson, results) |> Result.mapErr(Error.UnexpectedResponse)
                    ) yield list
                case Err(error) => Err(Error.UnexpectedResponse(error))
            }
            case Err(error) => Err(Error.NetworkError(error))
        }

    def checkOkField(json: Json): Result[Error, Json] = 
        match FromJson.getAtKey("ok", json) {
            case Ok(JBool(false)) => match FromJson.getAtKey("description", json) {
                case Ok(JString(desc)) => Err(Error.ErrorResponse(desc))
                case Ok(_) => Err(Error.ErrorResponse("Failed response, unable to decode description"))
                case Err(_) => Err(Error.ErrorResponse("Failed response, but no description"))
            }
            case Ok(JBool(true)) => Ok(json)
            case Ok(_) => Err(Error.ErrorResponse("Unknown status: 'ok' field is not a boolean"))
            case Err(_) => Err(Error.ErrorResponse("Unknown status: no 'ok' field"))
        }
}

