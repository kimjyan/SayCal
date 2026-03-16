import ComposableArchitecture

@Reducer
struct AddScheduleFeature {
    @ObservableState
    struct State: Equatable {
        var text = ""
    }

    enum Action {
        case textChanged(String)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .textChanged(text):
                state.text = text
                return .none
            }
        }
    }
}
