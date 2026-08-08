mod Planner.Tests {
    use State.StateMachine
    use Commands.Command
    use Planner.createPlan
    use Assert.assertEq
    use Planner.Actions.{AddItemToCategory, AddCategory, TransitionState, Reply}
    use Planner.Actions
    use Executor.ExecuteError
    use Storage.StorageError

    def runWithStateAndStorage(
            items: List[(String, List[String])], 
            state: StateMachine, f: Unit -> a \ ef): a \ (ef - Storage.StorageRead - State.StateRead) =
        run {
            f()
        } with handler Storage.StorageRead {
            def listCategories(resume) = 
                resume(Nil)

            def listTasksInCategory(category, resume) = 
                match List.find(t -> fst(t) == category, items) {
                    case Some((_, list)) => resume(Ok(list))
                    case None => resume(Err(StorageError.CategoryNotFound(category))) // let's return an error here to check the behavior on an eror
                    // TODO should differentiate between category not found and the error emitted from the method
                    // rn "test" is too generic to differentiate that
                }
            def categoryExists(category, resume) = 
                List.exists(t -> fst(t) == category, items) |> resume
        } with handler State.StateRead {
            def getState(resume) = 
                resume(state)
        }

    def test(
            command: { command = Command }, 
            initItems: { items = List[(String, List[String])] }, 
            initState: { state = StateMachine }, 
            expected: { expected = Result[Executor.ExecuteError, List[Actions]] }): Unit \ Assert = 
        run {
            createPlan(1i64, command#command) |>
                assertEq(expected = expected#expected)
        } with runWithStateAndStorage(initItems#items, initState#state)

    @Test
    def testAddCategoryIgnoresStateAndAddsCategoryAndReplies(): Unit \ Assert = 
        test(
            command = Command.AddCategory("New Category"),
            items = Nil,
            state = StateMachine.Nothing,
            expected = Ok(AddCategory("New Category") :: Reply(1i64, "Category added: New Category") :: Nil)
        )

    @Test
    def testAddCategoryItemWithEmptyCategoryShouldAddCategory(): Unit \ Assert = 
        test(
            command = Command.AddItemToCategory("New Category"),
            items = Nil,
            state = StateMachine.Nothing,
            expected = Ok(TransitionState(StateMachine.AddItemCategorySelected("New Category")) :: AddCategory("New Category") :: Reply(1i64, "Category added: New Category") :: Reply(1i64, "Type in item name") :: Nil)
        )

    @Test
    def testAddCategoryItemWithExistingCategoryShouldReplyWithTypeInItemName(): Unit \ Assert = 
        test(
            command = Command.AddItemToCategory("Existing Category"),
            items = ("Existing Category", Nil) :: Nil,
            state = StateMachine.Nothing,
            expected = Ok(TransitionState(StateMachine.AddItemCategorySelected("Existing Category")) :: Reply(1i64, "Type in item name") :: Nil)
        )


    @Test
    def testSimpleTextInAddItemStateShouldGenerateInsertAndReply(): Unit \ Assert = 
        test(
            command = Command.SimpleText("New Item"),
            items = ("Existing Category", Nil) :: Nil,
            state = StateMachine.AddItemCategorySelected("Existing Category"),
            expected = (TransitionState(StateMachine.Nothing) 
                       :: AddItemToCategory("Existing Category", "New Item") 
                       :: Reply(1i64, "New item to category Existing Category added: New Item") 
                       :: Nil) |> Ok
        )

    @Test
    def testOtherCommandInAddItemStateShouldAbortCommand(): Unit \ Assert = 
        test(
            command = Command.ListCategories,
            items = ("Existing Category", Nil) :: Nil,
            state = StateMachine.AddItemCategorySelected("Existing Category"),
            expected = Ok(TransitionState(StateMachine.Nothing) :: Reply(1i64, "Invalid command for the current state. Aborting.") :: Nil)
        )
    
    @Test
    def testListItemsForCategoryWithItemsShouldReplyFormattedList(): Unit \ Assert = 
        test(
            command = Command.ListItemsForCategory("Groceries"),
            items = ("Groceries", "Milk" :: "Bread" :: Nil) :: Nil,
            state = StateMachine.Nothing,
            expected = Ok(Reply(1i64, "📝 Items in category Groceries:\n🔹 Milk\n🔹 Bread") :: Nil)
        )

    @Test
    def testListItemsForCategoryWithNoItemsShouldReplyEmptyList(): Unit \ Assert = 
        test(
            command = Command.ListItemsForCategory("Groceries"),
            items = ("Groceries", Nil) :: Nil,
            state = StateMachine.Nothing,
            expected = Ok(Reply(1i64, "📝 Items in category Groceries:\n") :: Nil)
        )

    @Test
    def testListItemsForCategoryWhenCategoryDoesNotExistShouldReturnError(): Unit \ Assert = 
        test(
            command = Command.ListItemsForCategory("Nonexistent"),
            items = Nil,
            state = StateMachine.Nothing,
            expected = Err(ExecuteError.StorageReadError(StorageError.CategoryNotFound("Nonexistent")))
        )
    
    // TODO: add tests for list categories
}
