mod TelegramApi {
    use Util.Json.JsonPath.empty;
    use Util.Json.{JArray, decode, parse, Json, FromJson, JsonPath, JObject, JsonError, JBool, JString, JNumber}
    use Util.Json.JsonError.{JsonError, DecodeErrorKind}
    use Net.{HttpResponse, Https, HttpRequest}
    use Assert.{assertEq, assertErr}

    pub eff TelegramApi {
        def getLatestUpdateId(token: String, offset: Option[Int64]): Result[Error, Int64]
    }

    pub def runWithHttpsHandler(f: Unit -> a \ ef): a \ (ef - TelegramApi) + Https = 
        run {
            f()
        } with handler TelegramApi {
            def getLatestUpdateId(token, offset, resume) = 
                let updateId = getLatestUpdateIdFun(token, offset);
                resume(updateId)
        }

    pub enum Error with Eq, ToString {
        case NoUpdatesFound,
        case HttpRequestFailed(String),
        case JsonDecodeError(String, JsonError)
    }

    def bodyToString(body: Net.Body): String =
        match body {
            case Net.Body.Text(s) => s
            case Net.Body.Bytes(b) => String.fromBytes(b)
        }

    //TODO:
    // 1. Rename :)
    // 2. Tests for error handling types
    pub def getLatestUpdateIdFun(token: String, offset: Option[Int64]): Result[Error, Int64] \ { Https } =
        let url = match offset {
            case Some(o) => "https://api.telegram.org/${token}/getUpdates?offset=${o}&timeout=30"
            case None => "https://api.telegram.org/${token}/getUpdates"
        };
        let req = HttpRequest.get(url);
        match Https.send(req) {
           case Ok(Net.HttpResponse({status, body | _})) if status != 200 => Err(Error.HttpRequestFailed(bodyToString(body)))
           case Ok(response) => extractMaxUpdateIdFromHttpResponse(response)
           case Err(e) => Err(Error.HttpRequestFailed("HTTP request failed: ${e}"))
        }

    def extractMaxUpdateIdFromHttpResponse(response: HttpResponse): Result[Error, Int64] = 
        let body = HttpResponse.body(response);
        forM (
            json  <- parse(body) |> Result.mapErr(e -> Error.JsonDecodeError("Unable to parse response body", e));
            ids   <- extractUpdateIdsFromParsedJson(json);
            maxId <- findMaxUpdateId(ids)
        ) yield maxId

    def findMaxUpdateId(ids: List[Int64]): Result[Error, Int64] = 
        let max = List.maximum(ids);
        match max {
            case Some(id) => Ok(id)
            case None => Err(Error.NoUpdatesFound)
        }

    def extractUpdateIdsFromParsedJson(json: Json): Result[Error, List[Int64]] = 
        match FromJson.getAtKey("ok", json) {
            case Ok(JBool(false)) => match FromJson.getAtKey("description", json) {
                case Ok(JString(desc)) => Err(Error.HttpRequestFailed(desc))
                case Ok(_) => Err(Error.HttpRequestFailed("Request failed, but unable to extract description (wrong type)"))
                case Err(e) => Err(Error.HttpRequestFailed("Request failed, and unable to extract description: ${e}"))
            }
            case Ok(JBool(true)) => Result.mapErr(e -> Error.JsonDecodeError("Unable to parse result", e), extractUpdateIdsFromHttpParsedBody(json))
            case Ok(_) => Err(Error.HttpRequestFailed("Request failed, but unable to extract 'ok' field"))
            case Err(e) => Err(Error.HttpRequestFailed("Request failed, and unable to extract 'ok' field: ${e}"))
        }

    def extractUpdateIdsFromHttpParsedBody(json: Json): Result[JsonError, List[Int64]] =
        forM (
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

    @Test
    def testParsedUpdateId(): Unit \ Assert = 
        let json = JObject(Map#{"update_id" => JNumber(123ff)});
        assertEq(expected = Ok(123i64), extractId(json))

    @Test
    def testParseUpdateIdFailsOnString(): Unit \ Assert = 
        let json = JObject(Map#{"update_id" => JString("Not a number")});
        assertErr(extractId(json))

    @Test
    def testParseUpdateIdErrorOnMissingKey(): Unit\ Assert =
        let json = JObject(Map#{"other_key" => JNumber(11ff)});
        assertErr(extractId(json))
}
