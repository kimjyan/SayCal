import Dependencies
import EventKit
import UIKit

struct FetchUpcomingEventsUseCase: Sendable {
    var execute: @Sendable () async throws -> [EventInfo]
}

extension FetchUpcomingEventsUseCase: DependencyKey {
    static var liveValue: Self {
        .init {
            let store = EKEventStore()
            let granted = try await store.requestFullAccessToEvents()
            guard granted else { throw CalendarError.accessDenied }

            let writableCalendars = store.calendars(for: .event).filter { $0.allowsContentModifications }
            let savedID = UserDefaults.standard.string(forKey: selectedCalendarKey) ?? ""
            let target = writableCalendars.first { $0.calendarIdentifier == savedID }
                ?? store.defaultCalendarForNewEvents.flatMap { writableCalendars.contains($0) ? $0 : nil }
                ?? writableCalendars.first

            guard let calendar = target else { return [] }

            let now = Date()
            let cal = Calendar.current
            let start = cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: now)) ?? now
            let end = cal.date(byAdding: .day, value: 30, to: now) ?? now

            let predicate = store.predicateForEvents(withStart: start, end: end, calendars: [calendar])

            return store.events(matching: predicate)
                .sorted { $0.startDate < $1.startDate }
                .map { event in
                    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                    UIColor(cgColor: event.calendar.cgColor).getRed(&r, green: &g, blue: &b, alpha: &a)
                    return EventInfo(
                        id: event.eventIdentifier,
                        title: event.title ?? "(제목 없음)",
                        startDate: event.startDate,
                        isAllDay: event.isAllDay,
                        calendarTitle: event.calendar.title,
                        calendarRed: Double(r),
                        calendarGreen: Double(g),
                        calendarBlue: Double(b)
                    )
                }
        }
    }
}

extension DependencyValues {
    var fetchUpcomingEventsUseCase: FetchUpcomingEventsUseCase {
        get { self[FetchUpcomingEventsUseCase.self] }
        set { self[FetchUpcomingEventsUseCase.self] = newValue }
    }
}
