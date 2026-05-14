import Foundation

struct EventInfo: Equatable, Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let isAllDay: Bool
    let calendarTitle: String
    let calendarRed: Double
    let calendarGreen: Double
    let calendarBlue: Double
}
