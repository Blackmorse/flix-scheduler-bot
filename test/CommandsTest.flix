mod Commands.Tests {
    use Commands.CommandParseError
    use Assert.assertEq
    use Commands.{Command, FromString}

    @Test
    def testAddCategorySimple(): Unit \ Assert =
        FromString.fromString("/addCategory testCategory")
          |> assertEq(expected = Ok(Command.AddCategory("testCategory")))

    @Test
    def testAddCategoryMultiWordName(): Unit \ Assert =
        FromString.fromString("/addCategory some category name")
          |> assertEq(expected = Ok(Command.AddCategory("some category name")))

    @Test
    def testAddCategoryExtraSpacesBetween(): Unit \ Assert =
        FromString.fromString("/addCategory   spaced   out")
          |> assertEq(expected = Ok(Command.AddCategory("spaced   out")))

    @Test
    def testAddCategoryTrailingSpace(): Unit \ Assert =
        FromString.fromString("/addCategory name ")
          |> assertEq(expected = Ok(Command.AddCategory("name")))

    @Test
    def testAddCategoryLeadingSpaceAfterCommand(): Unit \ Assert =
        FromString.fromString("/addCategory  trimmed")
          |> assertEq(expected = Ok(Command.AddCategory("trimmed")))

    @Test
    def testAddCategoryNoName(): Unit \ Assert =
        (FromString.fromString("/addCategory"): Result[CommandParseError, Command])
          |> assertEq(expected = Err(CommandParseError.InvalidCommand("Empty argument for command: /addCategory")))

    @Test
    def testAddCategoryNoNameOnlySpaces(): Unit \ Assert =
        (FromString.fromString("/addCategory   "): Result[CommandParseError,Command])
          |> assertEq(expected = Err(CommandParseError.InvalidCommand("Empty argument for command: /addCategory")))

    @Test
    def testAddCategoryUnknownCommand(): Unit \ Assert =
        (FromString.fromString("/unknown foo"): Result[CommandParseError, Command])
          |> assertEq(expected = Err(CommandParseError.InvalidCommand("Unknown command: /unknown")))

    @Test
    def testAddCategoryEmptyString(): Unit \ Assert =
        (FromString.fromString(""): Result[CommandParseError, Command])
          |> assertEq(expected = Err(CommandParseError.InvalidCommand("Empty command string")))

    @Test
    def testAddCategoryWrongCaseCommand(): Unit \ Assert =
        (FromString.fromString("/addcategory test"): Result[CommandParseError, Command])
          |> assertEq(expected = Err(CommandParseError.InvalidCommand("Unknown command: /addcategory")))

    @Test
    def testAddCategoryNoSlash(): Unit \ Assert =
        FromString.fromString("addCategory test") 
          |> assertEq(expected = Ok(Command.SimpleText("addCategory test")))

    @Test
    def testAddCategoryCaseSensitiveSlashCommand(): Unit \ Assert =
        (FromString.fromString("/AddCategory test"): Result[CommandParseError, Command])
          |> assertEq(expected = Err(CommandParseError.InvalidCommand("Unknown command: /AddCategory")))

    @Test
    def testListCategoriesCommand(): Unit \ Assert =
        FromString.fromString("/listCategories") |> assertEq(expected = Ok(Command.ListCategories))

    @Test
    def testListCategoriesCommandWithTrailingSpaces(): Unit \ Assert =
        FromString.fromString("/listCategories   ") |> assertEq(expected = Ok(Command.ListCategories))

    @Test
    def testListCategoriesShouldntHaveArguments(): Unit \ Assert =
        (FromString.fromString("/listCategories extraArg"): Result[CommandParseError, Command])
          |> assertEq(expected = Err(CommandParseError.InvalidCommand("/listCategories command should not have arguments")))

    @Test
    def testAddItemToCategorySimple(): Unit \ Assert =
        FromString.fromString("/addItemToCategory testItem")
          |> assertEq(expected = Ok(Command.AddItemToCategory("testItem")))

    @Test
    def testAddItemToCategoryMultiWordName(): Unit \ Assert =
        FromString.fromString("/addItemToCategory some item name")
          |> assertEq(expected = Ok(Command.AddItemToCategory("some item name")))

    @Test
    def testAddItemToCategoryExtraSpacesBetween(): Unit \ Assert =
        FromString.fromString("/addItemToCategory   spaced   out")
          |> assertEq(expected = Ok(Command.AddItemToCategory("spaced   out")))

    @Test
    def testAddItemToCategoryTrailingSpace(): Unit \ Assert =
        FromString.fromString("/addItemToCategory name ")
          |> assertEq(expected = Ok(Command.AddItemToCategory("name")))

    @Test
    def testAddItemToCategoryLeadingSpaceAfterCommand(): Unit \ Assert =
        FromString.fromString("/addItemToCategory  trimmed")
          |> assertEq(expected = Ok(Command.AddItemToCategory("trimmed")))

    @Test
    def testAddItemToCategoryNoName(): Unit \ Assert =
        (FromString.fromString("/addItemToCategory"): Result[CommandParseError, Command])
          |> assertEq(expected = Err(CommandParseError.InvalidCommand("Empty argument for command: /addItemToCategory")))

    @Test
    def testAddItemToCategoryNoNameOnlySpaces(): Unit \ Assert =
        (FromString.fromString("/addItemToCategory   "): Result[CommandParseError, Command])
          |> assertEq(expected = Err(CommandParseError.InvalidCommand("Empty argument for command: /addItemToCategory")))

    @Test
    def otherMessagesRecognizedAsSimpleText(): Unit \ Assert =
        (FromString.fromString("Just a regular message"): Result[CommandParseError, Command])
          |> assertEq(expected = Ok(Command.SimpleText("Just a regular message")))

    @Test
    def testListItemsForCategoryHappyPath(): Unit \ Assert =
        FromString.fromString("/listItemsForCategory testCategory")
          |> assertEq(expected = Ok(Command.ListItemsForCategory("testCategory")))

    @Test
    def testListItemsForCategoryMultiWordName(): Unit \ Assert =
        FromString.fromString("/listItemsForCategory some category name")
          |> assertEq(expected = Ok(Command.ListItemsForCategory("some category name")))

    @Test
    def testListItemsForCategoryExtraSpacesBetween(): Unit \ Assert =
        FromString.fromString("/listItemsForCategory   spaced   out")
          |> assertEq(expected = Ok(Command.ListItemsForCategory("spaced   out")))

    @Test
    def testListItemsForCategoryTrailingSpace(): Unit \ Assert =
        FromString.fromString("/listItemsForCategory name ")
          |> assertEq(expected = Ok(Command.ListItemsForCategory("name")))

    @Test
    def testListItemsForCategoryLeadingSpaceAfterCommand(): Unit \ Assert =
        FromString.fromString("/listItemsForCategory  trimmed")
          |> assertEq(expected = Ok(Command.ListItemsForCategory("trimmed")))

    @Test
    def testListItemsForCategoryNoArgumentShouldFail(): Unit \ Assert =
        (FromString.fromString("/listItemsForCategory"): Result[CommandParseError, Command])
          |> assertEq(expected = Err(CommandParseError.InvalidCommand("Empty argument for command: /listItemsForCategory")))

    @Test
    def testListItemsForCategoryNoNameOnlySpaces(): Unit \ Assert =
        (FromString.fromString("/listItemsForCategory   "): Result[CommandParseError, Command])
          |> assertEq(expected = Err(CommandParseError.InvalidCommand("Empty argument for command: /listItemsForCategory")))
}
