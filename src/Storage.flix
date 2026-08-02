mod Storage {
    pub eff Storage {
        def addCategory(category: String): Unit
        def listCategories(): List[String]
    }
}

pub def runWithInMemoryStorage(rc: Region[r], f: Unit -> a \ ef): a \ (ef - Storage) + r = 
    let categoriesSet = MutSet.empty(rc);
    // pre-populate with some categories for testing
    MutSet.add("First category", categoriesSet);
    MutSet.add("Second category", categoriesSet);
    run {
        f()
    } with handler Storage {
        def addCategory(category, resume) = 
            let _ = MutSet.add(category, categoriesSet);
            resume(())
        

        def listCategories(resume) = 
            resume(MutSet.toList(categoriesSet))
    }
