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

    pub def runWithReadState(f: Unit -> a \ ef): a \ { ef - StateRead + State } = {
        run {
            f()
        } with handler StateRead {
            def getState(resume) = 
                State.getState() |> resume
        }
    }

    pub def runWithWriteState(f: Unit -> a \ ef): a \ { ef - StateWrite + State } = {
        run {
            f()
        } with handler StateWrite {
            def setState(newState, resume) = 
                State.setState(newState) |> resume
        }
    }

    pub def runWithInMemoryState(rc: Region[r], f: Unit -> a \ ef): a \ { ef - State + r } = {
        let state = Ref.fresh(rc, StateMachine.Nothing);
        run {
            f()
        } with handler State {
            def getState(resume) = 
                Ref.get(state) |> resume

            def setState(newState, resume) = 
                let _ = Ref.put(newState, state);
                resume(())
        }
    }
}
