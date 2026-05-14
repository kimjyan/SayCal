import ComposableArchitecture
import Foundation

@Reducer
struct RecentEventsFeature {
    @ObservableState
    struct State: Equatable {
        var events: [EventInfo] = []
        var isLoading = false
        var pendingDeletionID: String?
        var errorMessage: String?
    }

    enum Action {
        case onAppear
        case eventsLoaded(Result<[EventInfo], Error>)
        case deleteTapped(id: String)
        case deleteResponse(id: String, result: Result<Void, Error>)
        case errorDismissed
        case openInCalendarTapped(EventInfo)
    }

    @Dependency(\.fetchUpcomingEventsUseCase) var fetchEvents
    @Dependency(\.deleteEventUseCase) var deleteEvent

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    await send(.eventsLoaded(Result { try await fetchEvents.execute() }))
                }

            case let .eventsLoaded(.success(events)):
                state.isLoading = false
                state.events = events
                return .none

            case .eventsLoaded(.failure):
                state.isLoading = false
                state.errorMessage = "일정을 불러오지 못했어요."
                return .none

            case let .deleteTapped(id):
                state.pendingDeletionID = id
                return .run { send in
                    let result = await Result { try await deleteEvent.execute(id) }
                    await send(.deleteResponse(id: id, result: result))
                }

            case let .deleteResponse(id, .success):
                state.pendingDeletionID = nil
                state.events.removeAll { $0.id == id }
                return .none

            case .deleteResponse(_, .failure):
                state.pendingDeletionID = nil
                state.errorMessage = "이 일정을 삭제하지 못했어요."
                return .none

            case .errorDismissed:
                state.errorMessage = nil
                return .none

            case .openInCalendarTapped:
                return .none
            }
        }
    }
}

private extension Result where Failure == Error {
    init(catching body: () async throws -> Success) async {
        do {
            self = .success(try await body())
        } catch {
            self = .failure(error)
        }
    }
}
