mod TelegramApi.Tests {
    use Assert.{assertErr, fail, assertEq, assertTrue}
    use Net.{Https, HttpRequest}
    use Util.Json.JsonError
    use IoError.IoError
    use IoError.ErrorKind.ConnectionFailed

    def httpResponse(body: String): Net.HttpResponse = 
        Net.HttpResponse({
            body = Net.Body.Text(body),
            headers = Map#{},
            status = 200,
            url = ""
        })

    def textUpdateJsonString(updateId: Int64, text: String): String = 
        "{\"update_id\": ${updateId}, \"message\": {\"text\": \"${text}\"}}"

    @Test
    def testGetUpdatesReturnsNetworkErrorIfCaseOfRequestFailure(): Unit \ Assert = 
        run {
            let result = TelegramApi.getUpdates("some_token", None);
            match result {
                case Err(TelegramApi.Error.NetworkError(IoError(ConnectionFailed, _))) => ()
                case _ => fail("Expected an error, but got Ok")
            }
        } with handler Https {
            def request(_, resume) = 
                resume(Err(IoError(ConnectionFailed, "Simulated network failure")))
        }

    @Test
    def testTokenPassedToGetUpdates(): Unit \ Assert =
        run {
            let _ = TelegramApi.getUpdates("test_token");
            ()
        } with handler Https {
            def request(url, resume) = {
                assertTrue(String.contains(substr = "test_token", HttpRequest.url(url)));
                resume(Err(IoError(ConnectionFailed, "Simulated network failure")))
            }
        }

    // TODO: test offset is passed
    // TODO add Eq to Updates enum

    @Test
    def testGetUpdatesReceivedNonParseableBody(): Unit \ Assert = 
       run {
           match TelegramApi.getUpdates("test_token", None) {
               case Err(TelegramApi.Error.UnexpectedResponse(_)) => ()
               case _ => fail("Got OK or wrong error type, expected UnexpectedResponse")
           }
       } with handler Https {
           def request(_, resume) = resume(Ok(Net.HttpResponse({
               body = Net.Body.Text("This is not JSON"),
               headers = Map#{},
               status = 200,
               url = ""
           })))
       }

    @Test
    def testGetUpdatesNoOkFieldInResponse(): Unit \ Assert = 
        run {
            match TelegramApi.getUpdates("test_token", None) {
                case Err(TelegramApi.Error.ErrorResponse("Unknown status: no 'ok' field")) => ()
                case _ => fail("Got OK or wrong error type or wrong description, expected ErrorResponse")
            }
        } with handler Https {
            def request(_, resume) = resume(Ok(httpResponse("{\"description\": \"Test error description\"}")))
        }

    @Test
    def testGetUpdatesOkFieldNotBoolean(): Unit \ Assert = 
        run {
            match TelegramApi.getUpdates("test_token", None) {
                case Err(TelegramApi.Error.ErrorResponse("Unknown status: 'ok' field is not a boolean")) => ()
                case _ => fail("Got OK or wrong error type or wrong description, expected ErrorResponse")
            }
        } with handler Https {
            def request(_, resume) = resume(Ok(httpResponse("{\"ok\": \"not_a_boolean\", \"description\": \"Test error description\"}")))
        }

    @Test
    def testGetUpdatesNotOkStatusAndValidDescription(): Unit \ Assert = 
        run {
            match TelegramApi.getUpdates("test_token", None) {
                case Err(TelegramApi.Error.ErrorResponse("Test error description")) => ()
                case _ => fail("Got OK or wrong error type or wrong description, expected ErrorResponse")
            }
        } with handler Https {
            def request(_, resume) = resume(Ok(httpResponse("{\"ok\": false, \"description\": \"Test error description\"}")))
        }

    @Test
    def testGetUpdatesNotOkStatusAndNoDescriptionField(): Unit \ Assert = 
        run {
            match TelegramApi.getUpdates("test_token", None) {
                case Err(TelegramApi.Error.ErrorResponse("Failed response, but no description")) => ()
                case _ => fail("Got OK or wrong error type or wrong description, expected ErrorResponse")
            }
        } with handler Https {
            def request(_, resume) = resume(Ok(httpResponse("{\"ok\": false}")))
        }

    @Test
    def testGetUpdatesNotOkStatusAndInvalidDescriptionField(): Unit \ Assert =
        run {
            match TelegramApi.getUpdates("test_token", None) {
                case Err(TelegramApi.Error.ErrorResponse("Failed response, unable to decode description")) => ()
                case _ => fail("Got OK or wrong error type or wrong description, expected ErrorResponse")
            }
        } with handler Https {
            def request(_, resume) = resume(Ok(httpResponse("{\"ok\": false, \"description\": 123}")))
        }

    @Test
    def testGetUpdatesHasResultsAsNotArray(): Unit \ Assert = 
        run {
            match TelegramApi.getUpdates("test_token", None) {
                // TODO Path, message?
                case Err(TelegramApi.Error.UnexpectedResponse(JsonError.Decode(_, _))) => ()
                case _ => fail("Got OK or wrong error type or wrong description, expected ErrorResponse")
            }
        } with handler Https {
            def request(_, resume) = resume(Ok(httpResponse("{\"ok\": true, \"result\": {\"update_id\": 123}}")))
        }

    @Test
    def testGetTwoUpdatesFromValidResponse(): Unit \ Assert = 
        run {
            match TelegramApi.getUpdates("test_token", None) {
                case Ok(list) => assertEq(expected = 2, List.length(list))
                case _ => fail("Expected Ok with two updates")
            }
        } with handler Https {
            def request(_, resume) = resume(Ok(httpResponse("{\"ok\": true, \"result\": [${textUpdateJsonString(123i64, "Hello, world!")}, ${textUpdateJsonString(456i64, "Hello, world!")}] }")))
        }

    @Test
    def testGetThreeUpdatesFromValidResponse(): Unit \ Assert = 
        run {
            match TelegramApi.getUpdates("test_token", None) {
                case Ok(list) => assertEq(expected = 3, List.length(list))
                case _ => fail("Expected Ok with three updates")
            }
        } with handler Https {
            def request(_, resume) = resume(Ok(httpResponse("{\"ok\": true, \"result\": [${textUpdateJsonString(123i64, "Hello, world!")}, ${textUpdateJsonString(456i64, "Hello, world!")}, ${textUpdateJsonString(789i64, "Hello, world!")}] }")))
        }

    @Test
    def testGetUpdatesParsesTextMessage(): Unit \ Assert = 
        run {
            match TelegramApi.getUpdates("test_token", None) {
                case Ok(TelegramApi.TelegramUpdate.TextMessage({updateId, message}) :: Nil) => 
                    assertEq(expected = 123i64, updateId);
                    assertEq(expected = "Hello, world!", message)
                case _ => fail("Expected a single TextMessage update")
            }
        } with handler Https {
            def request(_, resume) = resume(Ok(httpResponse("{\"ok\": true, \"result\": [${textUpdateJsonString(123i64, "Hello, world!")}] }")))
        }
}
