mod Executor {
    use TelegramApi.Handler
    use TelegramApi.Handler.sendMessage
    use TelegramApi.Models.{OutgoingMessage, TelegramBotToken}
    use Planner.Actions
    use State.StateWrite
    use Net.Https
    use Storage.StorageWrite

    trait Executable[t] {
        type Aef: Eff
        pub def execute(self: t): Result[ExecuteError, Unit] \ Executable.Aef[t]
    }

    pub enum ExecuteError with Eq, ToString {
        case ParseError(Commands.CommandParseError),
        case SendMessageError(IoError)
        case StorageWriteError(Storage.StorageError)
    }

    def handleReply(chatId: Int64, text: String): Result[ExecuteError, Unit] \ { Https, TelegramBotToken } = 
         OutgoingMessage.TextMessage({chatId = chatId, text = text}) 
             |> sendMessage
             |> Result.mapErr(e -> match e {
                 case Handler.Error.MessageSendError(ioError) => ExecuteError.SendMessageError(ioError)
             })

    def handleTransition(newState: State.StateMachine): Result[ExecuteError, Unit] \ { StateWrite } =
        let _ = StateWrite.setState(newState);
        Ok(())

    def handleAddCategory(category: String): Result[ExecuteError, Unit] \ { StorageWrite } =
        StorageWrite.addCategory(category) 
        |> Result.mapErr(e -> ExecuteError.StorageWriteError(e))

    def handleAddItemToCategory(category: String, item: String): Result[ExecuteError, Unit] \ { StorageWrite } =
        StorageWrite.addTaskToCategory(category, item)
        |> Result.mapErr(e -> ExecuteError.StorageWriteError(e))

    instance Executable[Actions] {
        type Aef = {Https, TelegramBotToken, StateWrite, StorageWrite} 

        pub def execute(action: Planner.Actions): Result[ExecuteError, Unit] \ { Https, TelegramBotToken, StateWrite, StorageWrite } =
            match action {
                case Actions.Reply(chatId, text) => handleReply(chatId, text)
                case Actions.TransitionState(newState) => handleTransition(newState)
                case Actions.AddCategory(category) => handleAddCategory(category)
                case Actions.AddItemToCategory(category, item) => handleAddItemToCategory(category, item)
            }
    }
}
