import ComposableArchitecture
import Foundation

struct ParsedSchedule: Equatable {
    var date: String
    var time: String
}

@Reducer
struct AddScheduleFeature {
    @ObservableState
    struct State: Equatable {
        var text = ""
        var isLoading = false
    }

    enum Action {
        case textChanged(String)
        case addButtonTapped
        case parseResponse(Result<ParsedSchedule, Error>)
    }

    @Dependency(\.parseScheduleUseCase) var parseScheduleUseCase: ParseScheduleUseCase

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .textChanged(text):
                state.text = text
                return .none

            case .addButtonTapped:
                state.isLoading = true
                let text = state.text
                return .run { send in
                    await send(.parseResponse(
                        Result { try await parseScheduleUseCase.execute(text) }
                    ))
                }

            case .parseResponse:
                state.isLoading = false
                return .none
            }
        }
    }
}
