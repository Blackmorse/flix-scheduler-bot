mod Storage {
    pub eff Storage {
        def addCategory(category: String): Unit
        def listCategories(): List[String]
        def addTaskToCategory(category: String, task: String): Result[StorageError, Unit]
        def listTasksInCategory(category: String): Result[StorageError, List[String]]
        def categoryExists(category: String): Bool
    }

    pub eff StorageRead {
        def listCategories(): List[String]
        def listTasksInCategory(category: String): Result[StorageError, List[String]]
        def categoryExists(category: String): Bool
    }


    pub eff StorageWrite {
        def addCategory(category: String): Unit
        def addTaskToCategory(category: String, task: String): Result[StorageError, Unit]
    }

    pub enum StorageAction {
        case AddCategory(String),
        case ListCategories,
        case AddTaskToCategory(String, String), // (category, task)
        case ListTasksInCategory(String) // category
    }

    pub enum StorageError with Eq, ToString {
        case CategoryNotFound(String),
        case TaskAlreadyExists(String, String) // (category, task)
    }

    pub def runWithReadStorage(f: Unit -> a \ ef): a \ (ef - StorageRead) + Storage = 
        run {
            f()
        } with handler StorageRead {
            def listCategories(resume) = 
                Storage.listCategories() |> resume

            def listTasksInCategory(category, resume) = 
                Storage.listTasksInCategory(category) |> resume

            def categoryExists(category, resume) = 
                Storage.categoryExists(category) |> resume
        }

    pub def runWithWriteStorage(f: Unit -> a \ ef): a \ (ef - StorageWrite) + Storage = 
        run {
            f()
        } with handler StorageWrite {
            def addCategory(category, resume) = 
                let _ = Storage.addCategory(category);
                resume(())

            def addTaskToCategory(category, task, resume) = 
                Storage.addTaskToCategory(category, task) |> resume
        }

    pub def runWithInMemoryStorage(initialCategories: List[String],rc: Region[r], f: Unit -> a \ ef): a \ (ef - Storage) + r = 
        let categoriesMap = MutMap.empty(rc);
        // pre-populate with some categories for testing
        let _ = List.forEach(category -> MutMap.put(category, Set#{}, categoriesMap), initialCategories);
        run {
            f()
        } with handler Storage {
            def addCategory(category, resume) = 
                let _ = MutMap.put(category, Set#{}, categoriesMap);
                resume(())
            

            def listCategories(resume) = 
                MutMap.keysOf(categoriesMap) |> Set.toList |> resume

            def addTaskToCategory(category, task, resume) = 
                match MutMap.get(category, categoriesMap) {
                    case None => resume(Err(StorageError.CategoryNotFound(category)))
                    case Some(tasks) => 
                        if (Set.memberOf(task, tasks)) {
                            resume(Err(StorageError.TaskAlreadyExists(category, task)))
                        } else {
                            let _ = MutMap.put(category, Set.insert(task, tasks), categoriesMap);
                            resume(Ok(()))
                        }
                }

            def listTasksInCategory(category, resume) = 
                match MutMap.get(category, categoriesMap) {
                    case None => resume(Err(StorageError.CategoryNotFound(category)))
                    case Some(tasks) => resume(Ok(Set.toList(tasks)))
                }

            def categoryExists(category, resume) = 
                MutMap.get(category, categoriesMap) |> Option.nonEmpty |> resume

        }
}

