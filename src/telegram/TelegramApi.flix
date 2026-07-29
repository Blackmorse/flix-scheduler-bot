
mod TelegramApi {
    use Util.Json.{parse, JsonError, FromJson, JString, JBool, JArray, JsonError, JsonPath}
    use Util.Json.JsonError.DecodeErrorKind
    use Util.Json.JsonPath.JsonStep
    use Util.Json
    use Net.{Https, HttpRequest, HttpResponse}
    use JsonExt.getAsArray

    pub eff TelegramApi {
        def fetchUpdates(offset: Option[Int64]): Result[Error, List[TelegramUpdate]]
    }

    pub eff TelegramMessageSender {
        // TODO should be different error type (probably after splitting modules)
        def sendMessage(message: OutgoingMessage): Result[Error, Unit]
    }

    pub eff TelegramBotToken {
        def getToken(): String
    }

    pub eff UserMessageHandler {
        def handleMessage(message: TelegramUpdate): Unit
    }

    // TODO split module to loop-receiving part and message-sending part

    pub def runWithHttpsMessageSender(f: Unit -> a \ ef): a \ (ef - TelegramMessageSender) + Https + TelegramBotToken = 
        run {
            f()
        } with handler TelegramMessageSender {
          def sendMessage(message, resume) = {
              match message {
                  case TelegramApi.OutgoingMessage.TextMessage({chatId, text}) => 
                      let botToken = TelegramBotToken.getToken();
                      // TODO json serialization
                      let body = "{\"chat_id\": ${chatId}, \"text\": \"${text}\"}";
                      let req = HttpRequest.post("https://api.telegram.org/${botToken}/sendMessage", body)
                          |> HttpRequest.withContentType("application/json");
                      match Https.send(req) {
                          case Ok(_) => resume(Ok(()))
                          // TODO different error type
                          case Err(e) => resume(Err(Error.NetworkError(e)))
                      }
                 }
          }
        }

    @Tailrec
    pub def runLoop(offset: Option[Int64]): Result[TelegramApi.Error, Int64] \ { IO, TelegramApi, UserMessageHandler } = 
        let updates = match TelegramApi.fetchUpdates(offset) {
            case Ok(updates) => updates
            case Err(_) => Nil
        };
        let nextUpdate = updates |> List.map( update -> {
            let _ = UserMessageHandler.handleMessage(update);
            WithUpdateId.getUpdateId(update)
        }) |> List.maximum |> Option.map(id -> id + 1i64);
        println("Next update ID: ${nextUpdate}");
        runLoop(nextUpdate)

    sealed trait WithUpdateId[a] {
        pub def getUpdateId(a: a): Int64
    }

    instance WithUpdateId[TelegramUpdate] {
        pub def getUpdateId(update: TelegramUpdate): Int64 = match update {
            case TelegramUpdate.TextMessage({updateId | _}) => updateId
            case TelegramUpdate.OtherUpdate(updateId) => updateId
        }
    }

    pub def runWithHttpsHandler(f: Unit -> a \ ef): a \ (ef - TelegramApi) + Https + TelegramBotToken = 
        run {
            f()
        } with handler TelegramApi {
            def fetchUpdates(offset, resume) = 
                let updates = getUpdates(offset);
                resume(updates)
        }

    pub enum OutgoingMessage {
        case TextMessage({chatId = Int64, text = String})
    }

    pub def sendMessage(message: OutgoingMessage): Result[Error, Unit] \ TelegramMessageSender = 
        TelegramMessageSender.sendMessage(message)

    pub enum TelegramUpdate {
        case TextMessage({updateId = Int64, message = String, chatId = Int64})
        case OtherUpdate(Int64)
    }

    instance Eq[TelegramUpdate] {
        pub def eq(x: TelegramUpdate, y: TelegramUpdate): Bool = match (x, y) {
            case (TelegramUpdate.TextMessage(recordX), TelegramUpdate.TextMessage(recordY)) => recordX#updateId == recordY#updateId and recordX#message == recordY#message and recordX#chatId == recordY#chatId
            case (TelegramUpdate.OtherUpdate(idX), TelegramUpdate.OtherUpdate(idY)) => idX == idY
            case _ => false
        }
    }
    
    instance ToString[TelegramUpdate] {
        pub def toString(x: TelegramUpdate): String = match x {
            case TelegramUpdate.TextMessage(record) => "TextMessage(updateId=${record#updateId}, message=${record#message}, chatId=${record#chatId})"
            case TelegramUpdate.OtherUpdate(id) => "OtherUpdate(updateId=${id})"
        }
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
                message  <- JsonExt.getAsStringFromPath(JsonPath(JsonStep.Key("message") :: JsonStep.Key("text") :: Nil), j);
                chatId   <- JsonExt.getAsInt64FromPath(JsonPath(JsonStep.Key("message") :: JsonStep.Key("chat") :: JsonStep.Key("id") :: Nil), j)
                ) yield TelegramUpdate.TextMessage({updateId = updateId, message = message, chatId = chatId})
    }

    def getUpdates(offset: Option[Int64]): Result[Error, List[TelegramUpdate]] \ { Https, TelegramBotToken } = 
        let offsetSuffix = match offset {
            case Some(o) => "&offset=${o}"
            case None => ""
        };
        let token = TelegramBotToken.getToken();
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

