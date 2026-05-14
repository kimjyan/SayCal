import Dependencies
import EventKit

struct DeleteEventUseCase: Sendable {
    var execute: @Sendable (_ eventID: String) async throws -> Void
}

extension DeleteEventUseCase: DependencyKey {
    static var liveValue: Self {
        .init { eventID in
            let store = EKEventStore()
            let granted = try await store.requestFullAccessToEvents()
            guard granted else { throw CalendarError.accessDenied }

            guard let event = store.event(withIdentifier: eventID) else {
                throw CalendarError.eventNotFound
            }
            do {
                try store.remove(event, span: .thisEvent)
            } catch {
                throw CalendarError.saveFailed
            }
        }
    }
}

extension DependencyValues {
    var deleteEventUseCase: DeleteEventUseCase {
        get { self[DeleteEventUseCase.self] }
        set { self[DeleteEventUseCase.self] = newValue }
    }
}
