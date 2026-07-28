mod TelegramApi.Tests {
    use Assert.{assertErr, fail, assertEq, assertTrue}
    use Net.{Https, HttpRequest}
    use Util.Json.JsonError
    use IoError.IoError
    use IoError.ErrorKind.ConnectionFailed

    def botTokenHandler(token: String, f: Unit -> a \ ef): a \ (ef - TelegramApi.TelegramBotToken) =
        run {
            f()
        } with handler TelegramApi.TelegramBotToken {
            def getToken(resume) = resume(token)
        }

    def httpHandlerWithBody(body: String, f: Unit -> a \ ef): a \ (ef - Https) =
        run {
            f()
        } with handler Https {
            def request(_, resume) = resume(Ok(httpResponse(body)))
        }

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
            let result = TelegramApi.getUpdates(None);
            match result {
                case Err(TelegramApi.Error.NetworkError(IoError(ConnectionFailed, _))) => ()
                case _ => fail("Expected an error, but got Ok")
            }
        } with handler Https {
            def request(_, resume) = 
                resume(Err(IoError(ConnectionFailed, "Simulated network failure")))
        } with botTokenHandler("test_token")

    @Test
    def testTokenPassedToGetUpdates(): Unit \ Assert =
        run {
            let _ = TelegramApi.getUpdates(None);
            ()
        } with handler Https {
            def request(url, resume) = {
                assertTrue(String.contains(substr = "test_token", HttpRequest.url(url)));
                resume(Err(IoError(ConnectionFailed, "Simulated network failure")))
            }
        } with botTokenHandler("test_token")

    @Test
    def testOffsetPassedToGetUpdate(): Unit \ Assert = 
        run {
            let _ = TelegramApi.getUpdates(Some(123i64));
            ()
        } with handler Https {
            def request(url, resume) = {
                assertTrue(String.contains(substr = "offset=123", HttpRequest.url(url)));
                resume(Err(IoError(ConnectionFailed, "Simulated network failure")))
            }
        } with botTokenHandler("test_token")

    @Test
    def testOffsetNotPassedToGetUpdateWhenNone(): Unit \ Assert = 
        run {
            let _ = TelegramApi.getUpdates(None);
            ()
        } with handler Https {
            def request(url, resume) = {
                assertTrue(not String.contains(substr = "offset=", HttpRequest.url(url)));
                resume(Err(IoError(ConnectionFailed, "Simulated network failure")))
            }
        } with botTokenHandler("test_token")

    @Test
    def testGetUpdatesReceivedNonParseableBody(): Unit \ Assert = 
       run {
           match TelegramApi.getUpdates(None) {
               case Err(TelegramApi.Error.UnexpectedResponse(_)) => ()
               case _ => fail("Got OK or wrong error type, expected UnexpectedResponse")
           }
       } with httpHandlerWithBody("This is not JSON")
         with botTokenHandler("test_token")

    @Test
    def testGetUpdatesNoOkFieldInResponse(): Unit \ Assert = 
        run {
            assertEq(expected = Err(TelegramApi.Error.ErrorResponse("Unknown status: no 'ok' field")), TelegramApi.getUpdates(None))
        } with httpHandlerWithBody("{\"description\": \"Test error description\"}")
          with botTokenHandler("test_token")

    @Test
    def testGetUpdatesOkFieldNotBoolean(): Unit \ Assert = 
        run {
            assertEq(expected = Err(TelegramApi.Error.ErrorResponse("Unknown status: 'ok' field is not a boolean")), TelegramApi.getUpdates(None))
        } with httpHandlerWithBody("{\"ok\": \"not_a_boolean\", \"description\": \"Test error description\"}")
          with botTokenHandler("test_token")

    @Test
    def testGetUpdatesNotOkStatusAndValidDescription(): Unit \ Assert = 
        run {
            assertEq(expected = Err(TelegramApi.Error.ErrorResponse("Test error description")), TelegramApi.getUpdates(None))
        } with httpHandlerWithBody("{\"ok\": false, \"description\": \"Test error description\"}")
          with botTokenHandler("test_token")

    @Test
    def testGetUpdatesNotOkStatusAndNoDescriptionField(): Unit \ Assert = 
        run {
            assertEq(expected = Err(TelegramApi.Error.ErrorResponse("Failed response, but no description")), TelegramApi.getUpdates(None))
        } with httpHandlerWithBody("{\"ok\": false}")
          with botTokenHandler("test_token")

    @Test
    def testGetUpdatesNotOkStatusAndInvalidDescriptionField(): Unit \ Assert =
        run {
            assertEq(expected = Err(TelegramApi.Error.ErrorResponse("Failed response, unable to decode description")), TelegramApi.getUpdates(None))
        } with httpHandlerWithBody("{\"ok\": false, \"description\": 123}")
          with botTokenHandler("test_token")

    @Test
    def testGetUpdatesHasResultsAsNotArray(): Unit \ Assert = 
        run {
            match TelegramApi.getUpdates(None) {
                // TODO Path, message?
                case Err(TelegramApi.Error.UnexpectedResponse(JsonError.Decode(_, _))) => ()
                case _ => fail("Got OK or wrong error type or wrong description, expected ErrorResponse")
            }
        } with httpHandlerWithBody("{\"ok\": true, \"result\": {\"update_id\": 123}}")
          with botTokenHandler("test_token")

    @Test
    def testGetTwoUpdatesFromValidResponse(): Unit \ Assert = 
        run {
            match TelegramApi.getUpdates(None) {
                case Ok(list) => assertEq(expected = 2, List.length(list))
                case _ => fail("Expected Ok with two updates")
            }
        } with httpHandlerWithBody("{\"ok\": true, \"result\": [${textUpdateJsonString(123i64, "Hello, world!")}, ${textUpdateJsonString(456i64, "Hello, world!")}] }")
          with botTokenHandler("test_token")

    @Test
    def testGetThreeUpdatesFromValidResponse(): Unit \ Assert = 
        run {
            match TelegramApi.getUpdates(None) {
                case Ok(list) => assertEq(expected = 3, List.length(list))
                case _ => fail("Expected Ok with three updates")
            }
        } with httpHandlerWithBody("{\"ok\": true, \"result\": [${textUpdateJsonString(123i64, "Hello, world!")}, ${textUpdateJsonString(456i64, "Hello, world!")}, ${textUpdateJsonString(789i64, "Hello, world!")}] }")
          with botTokenHandler("test_token")

    @Test
    def testGetUpdatesParsesTextMessage(): Unit \ Assert = 
        run {
            assertEq(expected = Ok(List#{TelegramApi.TelegramUpdate.TextMessage({updateId = 123i64, message = "Hello, world!"})}), TelegramApi.getUpdates(None))
        } with httpHandlerWithBody("{\"ok\": true, \"result\": [${textUpdateJsonString(123i64, "Hello, world!")}] }")
          with botTokenHandler("test_token")
}
