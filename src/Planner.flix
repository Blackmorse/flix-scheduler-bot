mod Planner {
    use State.{StateRead, StateMachine}
    use Storage.StorageRead
    use Commands.Command
    use Executor.ExecuteError

    pub enum Actions with Eq, ToString {
        case Reply(Int64, String)
        case TransitionState(State.StateMachine)
        case AddCategory(String)
        case AddItemToCategory(String, String) // category, item
    }

    // TODO Error type is from execute - not nice
    // TODO formatting should be done separately
    pub def createPlan(chatId: Int64, command: Commands.Command): Result[Executor.ExecuteError, List[Actions]] \ { StorageRead, StateRead } = 
        match StateRead.getState() {
            case State.StateMachine.AddItemCategorySelected(category) => 
                match command {
                    case Command.SimpleText(text) => 
                        (Actions.TransitionState(StateMachine.Nothing)
                        :: Actions.AddItemToCategory(category, text) 
                        :: Actions.Reply(chatId, "New item to category ${category} added: ${text}") 
                        :: Nil)
                        |> Ok
                    case _ => 
                        (Actions.TransitionState(StateMachine.Nothing)
                        :: Actions.Reply(chatId, "Invalid command for the current state. Aborting.") 
                        :: Nil)
                        |> Ok
                }

            case StateMachine.Nothing => 
                match command {
                    case Command.AddCategory(category) => 
                        // todo if category already exists, show error
                        (Actions.AddCategory(category) 
                        :: Actions.Reply(chatId, "Category added: ${category}") 
                        :: Nil)
                        |> Ok
                    case Command.AddItemToCategory(category) => 
                        match StorageRead.categoryExists(category) {
                            case true => 
                                (Actions.TransitionState(StateMachine.AddItemCategorySelected(category))
                                :: Actions.Reply(chatId, "Type in item name") 
                                :: Nil)
                                |> Ok
                            case false => 
                                (Actions.TransitionState(StateMachine.AddItemCategorySelected(category)) 
                                :: Actions.AddCategory(category) 
                                :: Actions.Reply(chatId, "Category added: ${category}") 
                                :: Actions.Reply(chatId, "Type in item name") 
                                :: Nil)
                                |> Ok
                        }
                    case Command.ListCategories => 
                        let formatted = StorageRead.listCategories() |> List.map(c -> "🔹 ${c}") |> List.join("\n");
                        (Actions.Reply(chatId, "📂 Categories:\n${formatted}") :: Nil)
                        |> Ok
                    case Command.ListItemsForCategory(category) =>
                        match StorageRead.categoryExists(category) {
                            case true => 
                                // TODO handle now items separately?
                                StorageRead.listTasksInCategory(category) 
                                |> Result.map(items -> List.map(item -> "🔹 ${item}", items) 
                                |> List.join("\n"))
                                |> Result.map(text -> Actions.Reply(chatId, "📝 Items in category ${category}:\n${text}") :: Nil)
                                |> Result.mapErr(e -> ExecuteError.StorageReadError(e))
                            case false => Err(ExecuteError.StorageReadError(Storage.StorageError.CategoryNotFound(category)))
                        }
                    case _ => (Actions.Reply(chatId, "Unknown command.") :: Nil) |> Ok
                }
        }
}

