import ComposableArchitecture
import Foundation

let selectedCalendarKey = "selectedCalendarIdentifier"

@Reducer
struct CalendarSettingsFeature {
    @ObservableState
    struct State: Equatable {
        var calendars: [CalendarInfo] = []
        var selectedIdentifier: String = UserDefaults.standard.string(forKey: selectedCalendarKey) ?? ""
        var isLoading = false
    }

    enum Action {
        case onAppear
        case calendarsLoaded(Result<[CalendarInfo], Error>)
        case calendarSelected(CalendarInfo)
    }

    @Dependency(\.fetchCalendarsUseCase) var fetchCalendarsUseCase: FetchCalendarsUseCase

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    await send(.calendarsLoaded(
                        Result { try await fetchCalendarsUseCase.execute() }
                    ))
                }

            case let .calendarsLoaded(.success(calendars)):
                state.isLoading = false
                state.calendars = calendars
                if state.selectedIdentifier.isEmpty, let first = calendars.first {
                    state.selectedIdentifier = first.id
                    UserDefaults.standard.set(first.id, forKey: selectedCalendarKey)
                }
                return .none

            case .calendarsLoaded(.failure):
                state.isLoading = false
                return .none

            case let .calendarSelected(calendar):
                state.selectedIdentifier = calendar.id
                UserDefaults.standard.set(calendar.id, forKey: selectedCalendarKey)
                return .none
            }
        }
    }
}
