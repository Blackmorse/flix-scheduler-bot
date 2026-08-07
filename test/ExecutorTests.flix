mod Executor.Tests {
    use Executor.ExecuteError.{SendMessageError, StorageWriteError}
    use TelegramApi.Handler.Error.MessageSendError
    use TelegramApi.Models.runWithToken
    use Executor.{handleReply, handleTransition, handleAddCategory, handleAddItemToCategory}
    use State.{StateWrite, StateRead, StateMachine, runWithReadState, runWithWriteState, runWithInMemoryState}
    use Storage.{StorageWrite, StorageRead, runWithReadStorage, runWithWriteStorage, runWithInMemoryStorage}
    use Storage.StorageError.{CategoryNotFound, TaskAlreadyExists}
    use Net.{Body, Https, HttpResponse}
    use Assert.assertEq
    use IoError.ErrorKind.ConnectionFailed
    
    @Test
    def testHandleReplyShouldReturnOkWhenSendMessageSucceeds(): Unit \ Assert = run {
        handleReply(1i64, "Hello") |> assertEq(expected = Result.Ok(()))
    } with runWithToken("")
      with handler Https {
        def request(_, k) = k(Ok(HttpResponse({ body = Body.Text("OK"), headers = Map#{}, status = 200i32, url = ""})))
    }

    @Test
    def testHandleReplyShouldReturnIoErrorWhenSendMessageFails(): Unit \ Assert = run {
        let err = IoError(ConnectionFailed, "Connection failed");
        handleReply(1i64, "Hello") |> assertEq(expected = Result.Err(SendMessageError(err)))
    } with runWithToken("")
      with handler Https {
        def request(_, k) = k(Err(IoError(ConnectionFailed, "Connection failed")))
    }

    @Test
    def testHandleTransitionReturnsOk(): Unit \ Assert = region rc {
        run {
            handleTransition(StateMachine.Nothing) |> assertEq(expected = Result.Ok(()))
        } with runWithWriteState
          with runWithInMemoryState(rc)
    }

    @Test
    def testHandleTransitionReturnsOkForAddItemCategorySelected(): Unit \ Assert = region rc {
        run {
            handleTransition(StateMachine.AddItemCategorySelected("movies")) |> assertEq(expected = Result.Ok(()))
        } with runWithWriteState
          with runWithInMemoryState(rc)
    }

    @Test
    def testHandleTransitionSetsStateToNothing(): Unit \ Assert = region rc {
        run {
            let _ = handleTransition(StateMachine.Nothing);
            StateRead.getState()
            |> assertEq(expected = StateMachine.Nothing)
        } with runWithReadState
          with runWithWriteState
          with runWithInMemoryState(rc)
    }

    @Test
    def testHandleTransitionSetsStateToAddItemCategorySelected(): Unit \ Assert = region rc {
        run {
            let _ = handleTransition(StateMachine.AddItemCategorySelected("movies"));
            StateRead.getState()
            |> assertEq(expected = StateMachine.AddItemCategorySelected("movies"))
        } with runWithReadState
          with runWithWriteState
          with runWithInMemoryState(rc)
    }

    @Test
    def testHandleAddCategoryReturnsOk(): Unit \ Assert = region rc {
        run {
            handleAddCategory("movies") |> assertEq(expected = Result.Ok(()))
        } with runWithWriteStorage
          with runWithInMemoryStorage(Nil, rc)
    }

    @Test
    def testHandleAddCategoryAddsCategory(): Unit \ Assert = region rc {
        run {
            let _ = handleAddCategory("movies");
            StorageRead.listCategories()
            |> assertEq(expected = "movies" :: Nil)
        } with runWithReadStorage
          with runWithWriteStorage
          with runWithInMemoryStorage(Nil, rc)
    }

    @Test
    def testHandleAddCategoryAddsToExistingCategories(): Unit \ Assert = region rc {
        run {
            let _ = handleAddCategory("movies");
            StorageRead.listCategories()
            |> assertEq(expected = "books" :: "movies" :: Nil)
        } with runWithReadStorage
          with runWithWriteStorage
          with runWithInMemoryStorage("books" :: Nil, rc)
    }

    @Test
    def testHandleAddCategoryReturnsErrorWhenStorageFails(): Unit \ Assert = run {
        handleAddCategory("movies")
        |> assertEq(expected = Result.Err(StorageWriteError(CategoryNotFound("movies"))))
    } with handler StorageWrite {
        def addCategory(_category, k) = k(Err(CategoryNotFound("movies"))) // Not a valid error for addCategory, but can be used for test
        def addTaskToCategory(_category, _task, k) = k(Err(CategoryNotFound("movies")))
    }

    @Test
    def testHandleAddItemToCategoryReturnsOk(): Unit \ Assert = region rc {
        run {
            handleAddItemToCategory("movies", "Inception") |> assertEq(expected = Result.Ok(()))
        } with runWithWriteStorage
          with runWithInMemoryStorage("movies" :: Nil, rc)
    }

    @Test
    def testHandleAddItemToCategoryAddsItem(): Unit \ Assert = region rc {
        run {
            let _ = handleAddItemToCategory("movies", "Inception");
            StorageRead.listTasksInCategory("movies")
            |> assertEq(expected = Result.Ok("Inception" :: Nil))
        } with runWithReadStorage
          with runWithWriteStorage
          with runWithInMemoryStorage("movies" :: Nil, rc)
    }

    @Test
    def testHandleAddItemToCategoryAddsMultipleItems(): Unit \ Assert = region rc {
        run {
            let _ = handleAddItemToCategory("movies", "Inception");
            let _ = handleAddItemToCategory("movies", "Matrix");
            StorageRead.listTasksInCategory("movies")
            |> Result.map(items -> List.sort(items))
            |> assertEq(expected = Result.Ok("Inception" :: "Matrix" :: Nil))
        } with runWithReadStorage
          with runWithWriteStorage
          with runWithInMemoryStorage("movies" :: Nil, rc)
    }

    @Test
    def testHandleAddItemToCategoryReturnsErrorWhenCategoryMissing(): Unit \ Assert = region rc {
        run {
            handleAddItemToCategory("movies", "Inception")
            |> assertEq(expected = Result.Err(StorageWriteError(CategoryNotFound("movies"))))
        } with runWithWriteStorage
          with runWithInMemoryStorage(Nil, rc)
    }

    @Test
    def testHandleAddItemToCategoryReturnsErrorWhenItemAlreadyExists(): Unit \ Assert = region rc {
        run {
            let _ = handleAddItemToCategory("movies", "Inception");
            handleAddItemToCategory("movies", "Inception")
            |> assertEq(expected = Result.Err(StorageWriteError(TaskAlreadyExists("movies", "Inception"))))
        } with runWithWriteStorage
          with runWithInMemoryStorage("movies" :: Nil, rc)
    }
}
