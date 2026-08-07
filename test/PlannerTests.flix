mod Planner.Tests {
    use State.StateMachine
    use Commands.Command
    use Planner.createPlan
    use Assert.assertEq
    use Planner.Actions.{AddItemToCategory, AddCategory, TransitionState, Reply}

    def runWithStateAndStorage(categories: List[String], state: StateMachine, f: Unit -> a \ ef): a \ (ef - Storage.StorageRead - State.StateRead) =
        run {
            f()
        } with handler Storage.StorageRead {
            def listCategories(resume) = 
                resume(Nil)

            def listTasksInCategory(_, resume) = 
                resume(Ok(Nil))

            def categoryExists(category, resume) = 
                List.memberOf(category, categories) |> resume
        } with handler State.StateRead {
            def getState(resume) = 
                resume(state)
        }

    @Test
    def testAddCategoryIgnoresStateAndAddsCategoryAndReplies(): Unit \ Assert = run {
            createPlan(1i64, Command.AddCategory("New Category")) |>
                assertEq(expected = 
                    AddCategory("New Category") :: 
                    Reply(1i64, "Category added: New Category") :: Nil)
        } with runWithStateAndStorage(Nil, StateMachine.Nothing)

    @Test
    def testAddCategoryItemWithEmptyCategoryShouldAddCategory(): Unit \ Assert = run {
        createPlan(1i64, Command.AddItemToCategory("New Category")) |>
            assertEq(expected = 
                TransitionState(StateMachine.AddItemCategorySelected("New Category")) 
                :: AddCategory("New Category") 
                :: Reply(1i64, "Category added: New Category") 
                :: Reply(1i64, "Type in item name") :: Nil)
        } with runWithStateAndStorage(Nil, StateMachine.Nothing)

    @Test
    def testAddCategoryItemWithExistingCategoryShouldReplyWithTypeInItemName(): Unit \ Assert = run {
            createPlan(1i64, Command.AddItemToCategory("Existing Category")) |>
                assertEq(expected = 
                    TransitionState(StateMachine.AddItemCategorySelected("Existing Category")) 
                    :: Reply(1i64, "Type in item name") :: Nil)
        } with runWithStateAndStorage("Existing Category" :: Nil, StateMachine.Nothing)


    @Test
    def testSimpleTextInAddItemStateShouldGenerateInsertAndReply(): Unit \ Assert = run {
        createPlan(1i64, Command.SimpleText("New Item")) |>
            assertEq(expected = 
                AddItemToCategory("Existing Category", "New Item") 
                :: Reply(1i64, "New item to category Existing Category added: New Item") :: Nil)
    } with runWithStateAndStorage("Existing Category" :: Nil, StateMachine.AddItemCategorySelected("Existing Category"))

    @Test
    def testOtherCommandInAddItemStateShouldAbortCommand(): Unit \ Assert = run {
        createPlan(1i64, Command.ListCategories) |>
            assertEq(expected = 
                TransitionState(StateMachine.Nothing) 
                :: Reply(1i64, "Invalid command for the current state. Aborting.") :: Nil)
    } with runWithStateAndStorage("Existing Category" :: Nil, StateMachine.AddItemCategorySelected("Existing Category"))
    
    // TODO: add tests for list categories
}
