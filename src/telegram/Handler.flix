mod TelegramApi.Handler {
    use TelegramApi.Models.{TelegramUpdate, OutgoingMessage, TelegramBotToken}
    use Net.{Https, HttpRequest}

    pub eff UserMessageHandler {
        def handleMessage(message: TelegramUpdate): Unit
    }

    // no need to make public, there is no other options how to send messages now, apart for Https
    eff TelegramMessageSender {
        def sendMessage(message: OutgoingMessage): Result[Error, Unit]
    }

    pub def sendMessage(message: OutgoingMessage): Result[Error, Unit] \ Https + TelegramBotToken = 
        run {
            TelegramMessageSender.sendMessage(message)
        } with runWithHttpsMessageSender

    // TODO cover with tests, mocking Https
    def runWithHttpsMessageSender(f: Unit -> a \ ef): a \ (ef - TelegramMessageSender) + Https + TelegramBotToken = 
        run {
            f()
        } with handler TelegramMessageSender {
          def sendMessage(message, resume) = {
              match message {
                  case OutgoingMessage.TextMessage({chatId, text}) => 
                      let botToken = TelegramBotToken.getToken();
                      // TODO json serialization
                      let body = "{\"chat_id\": ${chatId}, \"text\": \"${text}\"}";
                      let req = HttpRequest.post("https://api.telegram.org/${botToken}/sendMessage", body)
                          |> HttpRequest.withContentType("application/json");
                      match Https.send(req) {
                          case Ok(_) => resume(Ok(()))
                          // TODO different error type
                          case Err(_) => resume(Err(Error.SomeError))
                      }
                 }
          }
        }

    // TODO
    pub enum Error {
        case SomeError
    }
}
