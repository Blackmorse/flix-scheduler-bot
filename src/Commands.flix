mod Commands {
    pub trait FromString[t] {
        pub def fromString(s: String): Option[t]
    }

    pub enum Command with Eq, ToString {
        case AddCategory(String),
        case ListCategories
    }

    def addCategoryPrefix(): String = "/addCategory"

    instance FromString[Command] {
        pub def fromString(s: String): Option[Command] = 
            if (String.startsWith(prefix = addCategoryPrefix(), s)) {
                let category = String.dropLeft(String.length(addCategoryPrefix()), s)
                 |> String.trim;
                 match category {
                     case "" => None
                     case _ => Some(Command.AddCategory(category))
                 }
            } else if (s == "/listCategories") Some(Command.ListCategories)
            else None
    }
}

