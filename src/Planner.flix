mod Planner {
    use State.{StateRead, StateMachine}
    use Storage.StorageRead
    use Commands.Command

    pub enum Actions with Eq, ToString {
        case Reply(Int64, String)
        case TransitionState(State.StateMachine)
        case AddCategory(String)
        case AddItemToCategory(String, String) // category, item
    }

    pub def formTransition(chatId: Int64, command: Commands.Command): List[Actions] \ { StorageRead, StateRead } = 
        match StateRead.getState() {
            case State.StateMachine.AddItemCategorySelected(category) => 
                match command {
                    case Command.SimpleText(text) => 
                        Actions.AddItemToCategory(category, text) :: 
                            Actions.Reply(chatId, "New item to category ${category} added: ${text}") :: Nil
                    case _ => Actions.TransitionState(StateMachine.Nothing) :: 
                        Actions.Reply(chatId, "Invalid command for the current state. Aborting.") :: Nil
                }

            case StateMachine.Nothing => 
                match command {
                    case Command.AddCategory(category) => 
                        // todo if category already exists, show error
                        Actions.AddCategory(category) :: Actions.Reply(chatId, "Category added: ${category}") :: Nil
                    case Command.AddItemToCategory(category) => 
                        match StorageRead.categoryExists(category) {
                            case true => Actions.TransitionState(StateMachine.AddItemCategorySelected(category)) :: 
                                Actions.Reply(chatId, "Type in item name") :: Nil
                            case false => Actions.TransitionState(StateMachine.AddItemCategorySelected(category)) :: 
                                Actions.AddCategory(category) :: 
                                Actions.Reply(chatId, "Category added: ${category}") :: 
                                Actions.Reply(chatId, "Type in item name") :: Nil
                        }
                    case Command.ListCategories => 
                        let categories = StorageRead.listCategories();
                        let formatted = List.map(c -> "🔹 ${c}", categories) |> List.join("\n");
                        Actions.Reply(chatId, "📂 Categories:\n${formatted}") :: Nil
                    case _ => Actions.Reply(chatId, "Unknown command.") :: Nil
                }
        }
}

