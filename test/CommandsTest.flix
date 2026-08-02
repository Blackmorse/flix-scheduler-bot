mod Commands.Tests {
    use Assert.assertEq
    use Commands.{Command, FromString}

    @Test
    def testAddCategorySimple(): Unit \ Assert =
        FromString.fromString("/addCategory testCategory")
          |> assertEq(expected = Some(Command.AddCategory("testCategory")))

    @Test
    def testAddCategoryMultiWordName(): Unit \ Assert =
        FromString.fromString("/addCategory some category name")
          |> assertEq(expected = Some(Command.AddCategory("some category name")))

    @Test
    def testAddCategoryExtraSpacesBetween(): Unit \ Assert =
        FromString.fromString("/addCategory   spaced   out")
          |> assertEq(expected = Some(Command.AddCategory("spaced   out")))

    @Test
    def testAddCategoryTrailingSpace(): Unit \ Assert =
        FromString.fromString("/addCategory name ")
          |> assertEq(expected = Some(Command.AddCategory("name")))

    @Test
    def testAddCategoryLeadingSpaceAfterCommand(): Unit \ Assert =
        FromString.fromString("/addCategory  trimmed")
          |> assertEq(expected = Some(Command.AddCategory("trimmed")))

    @Test
    def testAddCategoryNoName(): Unit \ Assert =
        (FromString.fromString("/addCategory"): Option[Command])
          |> assertEq(expected = None)

    @Test
    def testAddCategoryNoNameOnlySpaces(): Unit \ Assert =
        (FromString.fromString("/addCategory   "): Option[Command])
          |> assertEq(expected = None)

    @Test
    def testAddCategoryUnknownCommand(): Unit \ Assert =
        (FromString.fromString("/unknown foo"): Option[Command])
          |> assertEq(expected = None)

    @Test
    def testAddCategoryEmptyString(): Unit \ Assert =
        (FromString.fromString(""): Option[Command])
          |> assertEq(expected = None)

    @Test
    def testAddCategoryWrongCaseCommand(): Unit \ Assert =
        (FromString.fromString("/addcategory test"): Option[Command])
          |> assertEq(expected = None)

    @Test
    def testAddCategoryNoSlash(): Unit \ Assert =
        (FromString.fromString("addCategory test"): Option[Command])
          |> assertEq(expected = None)

    @Test
    def testAddCategoryCaseSensitiveSlashCommand(): Unit \ Assert =
        (FromString.fromString("/AddCategory test"): Option[Command])
          |> assertEq(expected = None)

    @Test
    def testListCategoriesCommand(): Unit \ Assert =
        FromString.fromString("/listCategories")
          |> assertEq(expected = Some(Command.ListCategories))

    @Test
    def testListCategoriesShouldntHaveArguments(): Unit \ Assert =
        (FromString.fromString("/listCategories extraArg"): Option[Command])
          |> assertEq(expected = None)
}
