import Dependencies
import EventKit
import UIKit

struct FetchCalendarsUseCase: Sendable {
    var execute: @Sendable () async throws -> [CalendarInfo]
}

extension FetchCalendarsUseCase: DependencyKey {
    static var liveValue: Self {
        .init {
            let store = EKEventStore()
            let granted = try await store.requestFullAccessToEvents()
            guard granted else { throw CalendarError.accessDenied }

            return store.calendars(for: .event)
                .filter { $0.allowsContentModifications }
                .map { calendar in
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                UIColor(cgColor: calendar.cgColor).getRed(&r, green: &g, blue: &b, alpha: &a)
                return CalendarInfo(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    red: Double(r),
                    green: Double(g),
                    blue: Double(b)
                )
            }
        }
    }
}

extension DependencyValues {
    var fetchCalendarsUseCase: FetchCalendarsUseCase {
        get { self[FetchCalendarsUseCase.self] }
        set { self[FetchCalendarsUseCase.self] = newValue }
    }
}
