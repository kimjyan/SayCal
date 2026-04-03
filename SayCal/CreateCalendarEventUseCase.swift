import Dependencies
import EventKit
import Foundation

struct CreateCalendarEventUseCase: Sendable {
    var execute: @Sendable (_ schedule: ParsedSchedule) async throws -> Void
}

extension CreateCalendarEventUseCase: DependencyKey {
    static var liveValue: Self {
        .init { schedule in
            let store = EKEventStore()

            let granted = try await store.requestFullAccessToEvents()
            guard granted else { throw CalendarError.accessDenied }

            let event = EKEvent(eventStore: store)
            event.title = schedule.title.isEmpty ? "일정" : schedule.title
            event.location = schedule.location.isEmpty ? nil : schedule.location
            event.calendar = store.defaultCalendarForNewEvents

            let (startDate, isAllDay) = parseDate(schedule)
            event.startDate = startDate
            event.isAllDay = isAllDay
            event.endDate = isAllDay ? startDate : Calendar.current.date(byAdding: .hour, value: 1, to: startDate)!

            try store.save(event, span: .thisEvent)
        }
    }
}

extension DependencyValues {
    var createCalendarEventUseCase: CreateCalendarEventUseCase {
        get { self[CreateCalendarEventUseCase.self] }
        set { self[CreateCalendarEventUseCase.self] = newValue }
    }
}

// MARK: - Private

private func parseDate(_ schedule: ParsedSchedule) -> (Date, isAllDay: Bool) {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")

    if !schedule.date.isEmpty && !schedule.time.isEmpty {
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        if let date = formatter.date(from: "\(schedule.date) \(schedule.time)") {
            return (date, false)
        }
    }

    if !schedule.date.isEmpty {
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: schedule.date) {
            return (date, true)
        }
    }

    return (Date(), false)
}

enum CalendarError: LocalizedError {
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .accessDenied: "캘린더 접근 권한이 필요합니다."
        }
    }
}
