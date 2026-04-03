import Dependencies
import Foundation
import FoundationModels

struct ParseScheduleUseCase: Sendable {
    var execute: @Sendable (_ text: String) async throws -> ParsedSchedule
}

extension ParseScheduleUseCase: DependencyKey {
    static var liveValue: Self {
        .init { text in
            let session = LanguageModelSession(instructions: makeInstructions())
            let response = try await session.respond(to: text, generating: ScheduleGenerableOutput.self)
            let content = response.content
            return ParsedSchedule(title: content.title, date: content.date, time: content.time, location: content.location)
        }
    }
}

extension DependencyValues {
    var parseScheduleUseCase: ParseScheduleUseCase {
        get { self[ParseScheduleUseCase.self] }
        set { self[ParseScheduleUseCase.self] = newValue }
    }
}

// MARK: - Private

private func makeInstructions() -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "ko-KR")
    dateFormatter.dateFormat = "yyyy-MM-dd"

    let weekdayFormatter = DateFormatter()
    weekdayFormatter.locale = Locale(identifier: "ko-KR")
    weekdayFormatter.dateFormat = "EEEE"

    let today = Date.now
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "ko-KR")
    calendar.firstWeekday = 2

    let weekday = calendar.component(.weekday, from: today)
    let daysFromMonday = (weekday + 5) % 7

    func weekEntry(offset: Int) -> String {
        let date = calendar.date(byAdding: .day, value: offset, to: today)!
        return "- \(weekdayFormatter.string(from: date)): \(dateFormatter.string(from: date))"
    }

    let todayStr = dateFormatter.string(from: today)
    let tomorrowStr = dateFormatter.string(from: calendar.date(byAdding: .day, value: 1, to: today)!)

    var thisWeek = (0...6).map { weekEntry(offset: $0 - daysFromMonday) }.joined(separator: "\n")
    var nextWeek = (7...13).map { weekEntry(offset: $0 - daysFromMonday) }.joined(separator: "\n")

    return """
    사용자가 입력한 일정 텍스트에서 날짜와 시간을 추출하세요.
    - 오전/오후를 24시간 형식으로 변환하세요. (오전 9시 → 09:00, 오후 9시 → 21:00)

    오늘: \(todayStr)
    내일: \(tomorrowStr)

    이번주:
    \(thisWeek)

    다음주:
    \(nextWeek)
    """
}

@Generable
private struct ScheduleGenerableOutput {
    @Guide(description: "일정의 제목. 날짜/시간/장소를 제외한 핵심 내용. 예: '이번주 금요일 오후 9시 병문안 강남역' → '병문안'. 없으면 빈 문자열.")
    var title: String

    @Guide(description: "일정의 날짜. 이번주/다음주/내일 등 상대적 표현을 오늘 기준 절대 날짜로 계산하여 yyyy-MM-dd 형식으로 반환. 예: 2026-03-20. 날짜 정보가 없으면 빈 문자열.")
    var date: String

    @Guide(description: "일정의 시간. 오전/오후를 24시간 형식으로 변환하여 HH:mm으로 반환. 오전 9시 → 09:00, 오후 9시 → 21:00, 오후 1시 → 13:00. 시간 정보가 없으면 빈 문자열.")
    var time: String

    @Guide(description: "일정의 장소. 예: '강남역', '회사', '집'. 장소 정보가 없으면 빈 문자열.")
    var location: String
}
