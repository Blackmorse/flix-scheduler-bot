mod State {
    pub eff State {
        def getState(): StateMachine
        def setState(newState: StateMachine): Unit
    }

    pub eff StateRead {
        def getState(): StateMachine
    }

    pub eff StateWrite {
        def setState(newState: StateMachine): Unit
    }

    pub enum StateMachine with Eq, ToString {
        case Nothing,
        case AddItemCategorySelected(String)
    }
}
