import Dependencies
import EventKit
import Foundation

struct CreateCalendarEventUseCase: Sendable {
    var execute: @Sendable (_ schedule: ParsedSchedule, _ durationMinutes: Int, _ alarmOffsetMinutes: Int, _ recurrence: Recurrence) async throws -> Date
}

extension CreateCalendarEventUseCase: DependencyKey {
    static var liveValue: Self {
        .init { schedule, durationMinutes, alarmOffsetMinutes, recurrence in
            let store = EKEventStore()

            let granted = try await store.requestFullAccessToEvents()
            guard granted else { throw CalendarError.accessDenied }

            let writableCalendars = store.calendars(for: .event).filter { $0.allowsContentModifications }
            let savedID = UserDefaults.standard.string(forKey: selectedCalendarKey) ?? ""
            let target = writableCalendars.first { $0.calendarIdentifier == savedID }
                ?? store.defaultCalendarForNewEvents.flatMap { writableCalendars.contains($0) ? $0 : nil }
                ?? writableCalendars.first

            guard let calendar = target else { throw CalendarError.noWritableCalendar }

            let event = EKEvent(eventStore: store)
            event.title = schedule.title.isEmpty ? "일정" : schedule.title
            event.location = schedule.location.isEmpty ? nil : schedule.location
            event.calendar = calendar

            let (startDate, isAllDay) = parseDate(schedule)
            event.startDate = startDate
            event.isAllDay = isAllDay
            if isAllDay {
                event.endDate = startDate
            } else {
                event.endDate = Calendar.current.date(byAdding: .minute, value: durationMinutes, to: startDate)
                    ?? startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
            }

            if alarmOffsetMinutes >= 0 {
                let alarm = EKAlarm(relativeOffset: TimeInterval(-alarmOffsetMinutes * 60))
                event.addAlarm(alarm)
            }

            if let frequency = recurrence.eventKitFrequency {
                let rule = EKRecurrenceRule(
                    recurrenceWith: frequency,
                    interval: 1,
                    end: nil
                )
                event.recurrenceRules = [rule]
            }

            do {
                try store.save(event, span: .thisEvent)
            } catch {
                throw CalendarError.saveFailed
            }

            return startDate
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

extension Recurrence {
    var eventKitFrequency: EKRecurrenceFrequency? {
        switch self {
        case .none:    nil
        case .daily:   .daily
        case .weekly:  .weekly
        case .monthly: .monthly
        case .yearly:  .yearly
        }
    }
}

enum CalendarError: LocalizedError {
    case accessDenied
    case noWritableCalendar
    case saveFailed
    case eventNotFound

    var errorDescription: String? {
        switch self {
        case .accessDenied:       "캘린더 접근 권한이 필요합니다."
        case .noWritableCalendar: "쓰기 가능한 캘린더가 없습니다."
        case .saveFailed:         "캘린더 저장에 실패했습니다."
        case .eventNotFound:      "이벤트를 찾을 수 없습니다."
        }
    }
}
