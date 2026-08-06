mod Storage.Tests {
    use Storage.{runWithInMemoryStorage, StorageError}
    use Assert.assertEq

    @Test
    def testCategoryIsAdded(): Unit \ Assert = region rc {
        run {
            Storage.addCategory("Test Category");
            let categories = Storage.listCategories();
            assertEq(expected = "Test Category" :: Nil, categories)
        } with runWithInMemoryStorage(Nil, rc)
    }

    @Test
    def testTwoDifferentCategoriesAreAdded(): Unit \ Assert = region rc {
        run {
            Storage.addCategory("Category Two");
            Storage.addCategory("Category One");
            let categories = Storage.listCategories();
            assertEq(expected = "Category One" :: "Category Two" :: Nil, List.sort(categories))
        } with runWithInMemoryStorage(Nil, rc)
    }

    // TODO error should be returned
    @Test
    def testDuplicatesCollapse(): Unit \ Assert = region rc {
        run {
            Storage.addCategory("Duplicate Category");
            Storage.addCategory("Duplicate Category");
            let categories = Storage.listCategories();
            assertEq(expected = "Duplicate Category" :: Nil, categories)
        } with runWithInMemoryStorage(Nil, rc)
    }

    @Test
    def testNewlyAddedCategoryHasNoTasks(): Unit \ Assert = region rc {
        run {
            Storage.addCategory("Solo");
            assertEq(expected = Ok(Nil), Storage.listTasksInCategory("Solo"))
        } with runWithInMemoryStorage(Nil, rc)
    }

    @Test
    def testAddTaskToNonExistingCategoryReturnsError(): Unit \ Assert = region rc {
        run {
            let result = Storage.addTaskToCategory("Ghost", "task1");
            assertEq(expected = Err(StorageError.CategoryNotFound("Ghost")), result)
        } with runWithInMemoryStorage(Nil, rc)
    }

    @Test
    def testAddTaskToExistingCategoryAndListTasks(): Unit \ Assert = region rc {
        run {
            Storage.addCategory("Work");
            let added = Storage.addTaskToCategory("Work", "Write tests");
            assertEq(expected = Ok(()), added);
            let tasks = Storage.listTasksInCategory("Work");
            assertEq(expected = Ok("Write tests" :: Nil), tasks)
        } with runWithInMemoryStorage(Nil, rc)
    }

    @Test
    def testAddDuplicatedTaskToCategoryShouldRiseError(): Unit \ Assert = region rc {
        run {
            Storage.addCategory("Dup");
            let _ = Storage.addTaskToCategory("Dup", "task");
            let result = Storage.addTaskToCategory("Dup", "task");
            assertEq(expected = Err(StorageError.TaskAlreadyExists("Dup", "task")), result)
        } with runWithInMemoryStorage(Nil, rc)
    }

    @Test
    def testAddTwoTasksToCategoryAndListThem(): Unit \ Assert = region rc {
        run {
            Storage.addCategory("Multi");
            let _ = Storage.addTaskToCategory("Multi", "taskB");
            let _ = Storage.addTaskToCategory("Multi", "taskA");
            Storage.listTasksInCategory("Multi") |> Result.map(List.sort) |> assertEq(expected = Ok("taskA" :: "taskB" :: Nil))
        } with runWithInMemoryStorage(Nil, rc)
    }

    @Test
    def testAddingNewCategoryShouldntDeleteTasks(): Unit \ Assert = region rc {
        run {
            Storage.addCategory("Cat1");
            let _ = Storage.addTaskToCategory("Cat1", "task1");
            Storage.addCategory("Cat2");
            Storage.listTasksInCategory("Cat1") |> assertEq(expected = Ok("task1" :: Nil))
        } with runWithInMemoryStorage(Nil, rc)
    }

    @Test
    def testCategoryExistsReturnsFalseForMissingCategory(): Unit \ Assert = region rc {
        run {
            assertEq(expected = false, Storage.categoryExists("Ghost"))
        } with runWithInMemoryStorage(Nil, rc)
    }

    @Test
    def testCategoryExistsReturnsTrueAfterAdd(): Unit \ Assert = region rc {
        run {
            Storage.addCategory("Work");
            assertEq(expected = true, Storage.categoryExists("Work"))
        } with runWithInMemoryStorage(Nil, rc)
    }
}
