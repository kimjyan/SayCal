import Foundation

enum ScheduleError: Error, Equatable {
    case parseFailure          // F1 — AI 파싱 실패
    case modelUnavailable      // F2 — FoundationModels 미가용
    case calendarPermission    // F3 — 캘린더 권한 거부
    case calendarSaveFailure   // F4 — 캘린더 저장 실패
    case speechFailure         // F5 — 음성 인식 실패

    var title: String {
        switch self {
        case .parseFailure:        "일정을 이해하지 못했어요"
        case .modelUnavailable:    "자동 분석을 사용할 수 없어요"
        case .calendarPermission:  "캘린더 권한이 필요해요"
        case .calendarSaveFailure: "캘린더에 저장하지 못했어요"
        case .speechFailure:       "음성 인식을 사용할 수 없어요"
        }
    }

    var message: String {
        switch self {
        case .parseFailure:        "직접 입력하거나 다시 시도해 주세요."
        case .modelUnavailable:    "이 기기에서는 자동 분석을 지원하지 않습니다."
        case .calendarPermission:  "설정 앱에서 캘린더 접근을 허용해 주세요."
        case .calendarSaveFailure: "선택한 캘린더에 저장할 수 없어요. 다른 캘린더를 선택해 주세요."
        case .speechFailure:       "텍스트로 입력해 주세요."
        }
    }

    var primaryActionLabel: String? {
        switch self {
        case .calendarPermission, .speechFailure: "설정 열기"
        case .calendarSaveFailure:                "캘린더 변경"
        default:                                  nil
        }
    }

    static func from(_ error: Error) -> ScheduleError {
        if let scheduleError = error as? ScheduleError {
            return scheduleError
        }
        if let calendarError = error as? CalendarError {
            switch calendarError {
            case .accessDenied:                       return .calendarPermission
            case .noWritableCalendar, .saveFailed:    return .calendarSaveFailure
            }
        }
        if error is SpeechError {
            return .speechFailure
        }
        return .parseFailure
    }
}
