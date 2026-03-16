import Dependencies
import Foundation
import FoundationModels

struct ParseScheduleUseCase: Sendable {
    var execute: @Sendable (_ text: String) async throws -> ParsedSchedule
}

extension ParseScheduleUseCase: DependencyKey {
    static var liveValue: Self {
        .init { text in
            let today = Date.now.formatted(.dateTime.year().month().day().weekday(.wide))
            let session = LanguageModelSession(
                instructions: "오늘은 \(today)입니다. 사용자가 입력한 일정 텍스트에서 날짜와 시간을 추출하세요."
            )
            let response = try await session.respond(to: text, generating: ScheduleGenerableOutput.self)
            return ParsedSchedule(date: response.content.date, time: response.content.time)
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

@Generable
private struct ScheduleGenerableOutput {
    @Guide(description: "일정의 날짜 (yyyy-MM-dd 형식, 예: 2026-03-21). 날짜 정보가 없으면 빈 문자열.")
    var date: String

    @Guide(description: "일정의 시간 (HH:mm 24시간 형식, 예: 15:00). 시간 정보가 없으면 빈 문자열.")
    var time: String
}
