mod TelegramApi {
    use Util.Json.JsonPath.empty;
    use Util.Json.{JArray, decode, parse, Json, FromJson, JsonPath, JObject, JsonError}
    use Util.Json.JsonError.{JsonError, DecodeErrorKind}
    use Net.{HttpResponse, Https}

    pub eff TelegramApi {
        def getLatestUpdateId(token: String, offset: Option[Int64]): Result[JsonError, Int64]
    }

    pub def runWithHttpsHandler(f: Unit -> a \ ef): a \ (ef - TelegramApi) + Https = 
        run {
            f()
        } with handler TelegramApi {
            def getLatestUpdateId(token, offset, resume) = 
                let updateId = getLatestUpdateIdFun(token, offset);
                resume(updateId)
        }

    // TODO: 
    // 1. Create enum with an errors
    // 2. Errors might be of different nature - like network, request error(4xx, 5xx etc etc)
    // 3. Test all of that failing scenarios by providing Https handler for tests
    pub def getLatestUpdateIdFun(token: String, offset: Option[Int64]): Result[JsonError, Int64] \ { Https } =
        let url = match offset {
            case Some(o) => "https://api.telegram.org/${token}/getUpdates?offset=${o}"
            case None => "https://api.telegram.org/${token}/getUpdates"
        };
        match Https.get(url) {
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

    pub def extractUpdateIdsFromHttpResponseBody(body: String): Result[JsonError, List[Int64]] =
        forM (
            json <- parse(body);
            result <- FromJson.getAtKey("result", json);
            ids <- match result {
                case JArray(v) => Result.traverse(extractId, Vector.toList(v))
                case _ => Err(JsonError.Decode(JsonPath.empty(), DecodeErrorKind.TypeMismatch("expected array")))
            }
        ) yield ids

    pub def extractId(j: Json): Result[JsonError, Int64] =
      match j {
         case JObject(_) => FromJson.decodeAtKey("update_id", j)
         case _          => Err(JsonError.Decode(JsonPath.empty(),            
                                     DecodeErrorKind.TypeMismatch("expected object")))
     }
}
