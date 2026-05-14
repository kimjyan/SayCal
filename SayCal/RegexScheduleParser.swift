import Foundation

enum RegexScheduleParser {
    static func parse(_ text: String, now: Date = Date()) -> (date: String, time: String, durationMinutes: Int) {
        (extractDate(text, now: now), extractTime(text), extractDurationMinutes(text))
    }

    static func extractDurationMinutes(_ text: String) -> Int {
        var total = 0

        if let result = capture(pattern: #"(\d{1,2})\s*시간\s*(\d{1,2})\s*분"#, in: text, groupCount: 2),
           let hours = Int(result[0]), let minutes = Int(result[1]) {
            total = hours * 60 + minutes
        } else if let result = capture(pattern: #"(\d{1,2})\s*시간\s*반"#, in: text, groupCount: 1),
                  let hours = Int(result[0]) {
            total = hours * 60 + 30
        } else if let result = capture(pattern: #"(\d{1,2})\s*시간"#, in: text, groupCount: 1),
                  let hours = Int(result[0]) {
            total = hours * 60
        } else if let result = capture(pattern: #"(\d{1,3})\s*분(?!\s*전)"#, in: text, groupCount: 1),
                  let minutes = Int(result[0]) {
            total = minutes
        }

        return (total > 0 && total <= 24 * 60) ? total : 0
    }

    static func extractDate(_ text: String, now: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ko_KR")
        calendar.firstWeekday = 2

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        if text.contains("글피") {
            return formatter.string(from: calendar.date(byAdding: .day, value: 3, to: now)!)
        }
        if text.contains("모레") {
            return formatter.string(from: calendar.date(byAdding: .day, value: 2, to: now)!)
        }
        if text.contains("내일") {
            return formatter.string(from: calendar.date(byAdding: .day, value: 1, to: now)!)
        }
        if text.contains("오늘") {
            return formatter.string(from: now)
        }

        if let weekdayOffset = weekdayOffset(in: text, now: now, calendar: calendar) {
            return formatter.string(from: calendar.date(byAdding: .day, value: weekdayOffset, to: now)!)
        }

        if let monthDay = monthDayDate(in: text, now: now, calendar: calendar) {
            return formatter.string(from: monthDay)
        }

        return ""
    }

    static func extractTime(_ text: String) -> String {
        if text.contains("정오") { return "12:00" }
        if text.contains("자정") { return "00:00" }

        if let (hour, minute) = matchHourMinute(text, prefix: "오전") {
            let normalized = hour == 12 ? 0 : hour
            return formatTime(hour: normalized, minute: minute)
        }
        if let (hour, minute) = matchHourMinute(text, prefix: "오후") {
            let normalized = hour == 12 ? 12 : hour + 12
            return formatTime(hour: normalized, minute: minute)
        }
        if let (hour, minute) = matchBareTime(text) {
            return formatTime(hour: hour, minute: minute)
        }
        return ""
    }

    // MARK: - Helpers

    private static let weekdayMap: [(String, Int)] = [
        ("월", 2), ("화", 3), ("수", 4), ("목", 5), ("금", 6), ("토", 7), ("일", 1),
    ]

    private static func weekdayOffset(in text: String, now: Date, calendar: Calendar) -> Int? {
        guard let foundDay = weekdayMap.first(where: { text.contains("\($0.0)요일") || text.contains("\($0.0)욜") })?.1 else {
            return nil
        }

        let todayWeekday = calendar.component(.weekday, from: now)
        let todayOffsetFromMonday = (todayWeekday + 5) % 7
        let targetOffsetFromMonday = (foundDay + 5) % 7
        var offset = targetOffsetFromMonday - todayOffsetFromMonday

        if text.contains("다음주") || text.contains("담주") {
            offset += 7
        } else if !text.contains("이번주") && offset < 0 {
            offset += 7
        }
        return offset
    }

    private static func monthDayDate(in text: String, now: Date, calendar: Calendar) -> Date? {
        let pattern = #"(\d{1,2})\s*월\s*(\d{1,2})\s*일"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let monthRange = Range(match.range(at: 1), in: text),
              let dayRange = Range(match.range(at: 2), in: text),
              let month = Int(text[monthRange]),
              let day = Int(text[dayRange]) else { return nil }

        var components = calendar.dateComponents([.year], from: now)
        components.month = month
        components.day = day
        guard let candidate = calendar.date(from: components) else { return nil }

        if candidate < calendar.startOfDay(for: now) {
            components.year = (components.year ?? 0) + 1
            return calendar.date(from: components)
        }
        return candidate
    }

    private static func matchHourMinute(_ text: String, prefix: String) -> (Int, Int)? {
        let patternWithMin = "\(prefix)\\s*(\\d{1,2})\\s*시\\s*(\\d{1,2})\\s*분"
        if let result = capture(pattern: patternWithMin, in: text, groupCount: 2),
           let hour = Int(result[0]), let minute = Int(result[1]) {
            return (hour, minute)
        }
        let patternColonMin = "\(prefix)\\s*(\\d{1,2}):(\\d{2})"
        if let result = capture(pattern: patternColonMin, in: text, groupCount: 2),
           let hour = Int(result[0]), let minute = Int(result[1]) {
            return (hour, minute)
        }
        let patternHourOnly = "\(prefix)\\s*(\\d{1,2})\\s*시"
        if let result = capture(pattern: patternHourOnly, in: text, groupCount: 1),
           let hour = Int(result[0]) {
            return (hour, 0)
        }
        return nil
    }

    private static func matchBareTime(_ text: String) -> (Int, Int)? {
        if let result = capture(pattern: #"(\d{1,2})\s*시\s*(\d{1,2})\s*분"#, in: text, groupCount: 2),
           let hour = Int(result[0]), let minute = Int(result[1]) {
            return (hour, minute)
        }
        if let result = capture(pattern: #"(\d{1,2}):(\d{2})"#, in: text, groupCount: 2),
           let hour = Int(result[0]), let minute = Int(result[1]) {
            return (hour, minute)
        }
        if let result = capture(pattern: #"(\d{1,2})\s*시"#, in: text, groupCount: 1),
           let hour = Int(result[0]) {
            return (hour, 0)
        }
        return nil
    }

    private static func capture(pattern: String, in text: String, groupCount: Int) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges == groupCount + 1 else { return nil }

        var captures: [String] = []
        for i in 1...groupCount {
            guard let r = Range(match.range(at: i), in: text) else { return nil }
            captures.append(String(text[r]))
        }
        return captures
    }

    private static func formatTime(hour: Int, minute: Int) -> String {
        let h = max(0, min(23, hour))
        let m = max(0, min(59, minute))
        return String(format: "%02d:%02d", h, m)
    }
}
