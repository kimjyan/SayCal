import AppIntents
import Foundation

struct AddScheduleIntent: AppIntent {
    static var title: LocalizedStringResource = "일정 추가"
    static var description = IntentDescription("자연어 한 문장으로 캘린더에 일정을 추가합니다.")
    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "일정",
        description: "예: 이번주 토요일 3시 강남역",
        inputOptions: .init(multiline: false, autocorrect: false)
    )
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$text)을(를) 캘린더에 추가")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let parsed = try await ParseScheduleUseCase.liveValue.execute(text)
        guard !parsed.date.isEmpty else {
            return .result(dialog: "일정의 날짜를 알 수 없어요. 더 구체적으로 말씀해 주세요.")
        }

        let duration = parsed.durationMinutes > 0 ? parsed.durationMinutes : 60
        let startDate = try await CreateCalendarEventUseCase.liveValue.execute(
            parsed, duration, parsed.alarmOffsetMinutes, parsed.recurrence
        )

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateStyle = .medium
        formatter.timeStyle = parsed.time.isEmpty ? .none : .short
        let dateString = formatter.string(from: startDate)
        let title = parsed.title.isEmpty ? "일정" : parsed.title

        return .result(dialog: "\(title), \(dateString)에 추가했어요.")
    }
}

struct SayCalShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddScheduleIntent(),
            phrases: [
                "\(.applicationName)에 일정 추가",
                "\(.applicationName) 일정 등록",
                "\(.applicationName)으로 일정 추가",
            ],
            shortTitle: "일정 추가",
            systemImageName: "calendar.badge.plus"
        )
    }
}
