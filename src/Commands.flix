mod Commands {
    pub trait FromString[t] {
        pub def fromString(s: String): Result[CommandParseError, t]
    }

    pub enum Command with Eq, ToString {
        case AddCategory(String),
        case AddItemToCategory(String),
        case ListCategories,
        case ListItemsForCategory(String),
        case SimpleText(String)
    }

    def addCategoryPrefix(): String = "/addCategory"
    def addItemToCategoryPrefix(): String = "/addItemToCategory"
    def listCategoriesCommandPrefix(): String = "/listCategories"
    def listItemsForCategoryPrefix(): String = "/listItemsForCategory"

    def parseCommandWithArgument(s: String, prefix: String): Result[CommandParseError, String] = 
        if (String.startsWith(prefix = prefix, s)) {
            let argument = String.dropLeft(String.length(prefix), s)
             |> String.trim;
             match argument {
                 case "" => Err(CommandParseError.InvalidCommand("Empty argument for command: ${prefix}"))
                 case _ => Ok(argument)
             }
        } else Err(CommandParseError.InvalidCommand("Command does not start with expected prefix: ${prefix}"))

    pub enum CommandParseError with Eq, ToString {
        case InvalidCommand(String)
    }

    instance FromString[Command] {
        pub def fromString(s: String): Result[CommandParseError, Command] = 
            if (String.startsWith(prefix = addCategoryPrefix(), s)) {
                parseCommandWithArgument(s, addCategoryPrefix()) 
                  |> Result.map(arg -> Command.AddCategory(arg))
            } else if (String.startsWith(prefix = addItemToCategoryPrefix(), s)) {
                parseCommandWithArgument(s, addItemToCategoryPrefix()) 
                  |> Result.map(arg -> Command.AddItemToCategory(arg))
            } else if (String.startsWith(prefix = listItemsForCategoryPrefix(), s)) {
                parseCommandWithArgument(s, listItemsForCategoryPrefix()) 
                  |> Result.map(arg -> Command.ListItemsForCategory(arg))
            } else if (String.startsWith(prefix = listCategoriesCommandPrefix(), s)) {
                if (String.trim(s) != listCategoriesCommandPrefix()) {
                    Err(CommandParseError.InvalidCommand("${listCategoriesCommandPrefix()} command should not have arguments"))
                } else {
                    Ok(Command.ListCategories)
                }
            } else if (String.startsWith(prefix = "/", s)) {
                  let commandOpt = unchecked_cast(s |> String.split(regex = " ") |> List.head);
                  match commandOpt {
                      case Some(command) => Err(CommandParseError.InvalidCommand("Unknown command: ${command}"))
                      case _ => ??? // should be impossible, since we already checked that s starts with "/"
                  }
            } else if (String.isEmpty(s)) Err(CommandParseError.InvalidCommand("Empty command string"))
              else Ok(Command.SimpleText(s))
    }
}

