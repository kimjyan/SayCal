import ComposableArchitecture
import Foundation
import UIKit

struct ParsedSchedule: Equatable {
    var title: String
    var date: String
    var time: String
    var location: String
    var durationMinutes: Int = 0          // 0 = 미지정 (UI에서 기본 60 적용)
    var alarmOffsetMinutes: Int = -1      // -1 = 알람 없음
}

@Reducer
struct AddScheduleFeature {
    @ObservableState
    struct State: Equatable {
        var text = ""
        var isLoading = false
        var isRecording = false
        var isSettingsPresented = false
        var savedSummary: SavedSummary?
        var errorAlert: ErrorState?
        @Presents var confirmation: ConfirmScheduleFeature.State?

        struct SavedSummary: Equatable {
            let title: String
            let dateLabel: String
            let startDate: Date
        }

        struct ErrorState: Equatable {
            let error: ScheduleError
        }
    }

    enum Action {
        case textChanged(String)
        case addButtonTapped
        case micButtonTapped
        case transcriptionUpdated(String)
        case recordingFinished
        case speechFailed
        case parseResponse(Result<ParsedSchedule, ScheduleError>)
        case calendarEventResponse(Result<CalendarSaveOutcome, ScheduleError>)
        case confirmation(PresentationAction<ConfirmScheduleFeature.Action>)
        case settingsButtonTapped
        case settingsDismissed
        case savedSummaryDismissed
        case openSavedEventTapped
        case errorDismissed
        case errorPrimaryActionTapped
        case openSettings
    }

    struct CalendarSaveOutcome: Equatable {
        let schedule: ParsedSchedule
        let startDate: Date
    }

    private enum CancelID { case recording }

    @Dependency(\.parseScheduleUseCase) var parseScheduleUseCase: ParseScheduleUseCase
    @Dependency(\.createCalendarEventUseCase) var createCalendarEventUseCase: CreateCalendarEventUseCase
    @Dependency(\.speechRecognitionUseCase) var speechRecognitionUseCase: SpeechRecognitionUseCase

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .textChanged(text):
                state.text = text
                return .none

            case .addButtonTapped:
                state.isLoading = true
                let text = state.text
                return .run { send in
                    let result: Result<ParsedSchedule, ScheduleError>
                    do {
                        let parsed = try await parseScheduleUseCase.execute(text)
                        if parsed.date.isEmpty {
                            result = .failure(.parseFailure)
                        } else {
                            result = .success(parsed)
                        }
                    } catch {
                        result = .failure(ScheduleError.from(error))
                    }
                    await send(.parseResponse(result))
                }

            case let .parseResponse(.success(schedule)):
                state.isLoading = false
                state.confirmation = ConfirmScheduleFeature.State(parsed: schedule)
                return .none

            case let .parseResponse(.failure(error)):
                state.isLoading = false
                state.errorAlert = .init(error: error)
                return .none

            case let .confirmation(.presented(.delegate(.save(schedule, durationMinutes, alarmOffsetMinutes)))):
                state.confirmation = nil
                state.isLoading = true
                return .run { send in
                    let result: Result<CalendarSaveOutcome, ScheduleError>
                    do {
                        let startDate = try await createCalendarEventUseCase.execute(
                            schedule, durationMinutes, alarmOffsetMinutes
                        )
                        result = .success(.init(schedule: schedule, startDate: startDate))
                    } catch {
                        result = .failure(ScheduleError.from(error))
                    }
                    await send(.calendarEventResponse(result))
                }

            case .confirmation(.presented(.delegate(.cancel))):
                state.confirmation = nil
                return .none

            case .confirmation:
                return .none

            case let .calendarEventResponse(.success(outcome)):
                state.isLoading = false
                state.text = ""
                state.savedSummary = .init(
                    title: outcome.schedule.title.isEmpty ? "일정" : outcome.schedule.title,
                    dateLabel: formatSummary(outcome.schedule),
                    startDate: outcome.startDate
                )
                return .none

            case let .calendarEventResponse(.failure(error)):
                state.isLoading = false
                state.errorAlert = .init(error: error)
                return .none

            case .micButtonTapped:
                if state.isRecording {
                    state.isRecording = false
                    return .cancel(id: CancelID.recording)
                } else {
                    state.isRecording = true
                    return .run { send in
                        do {
                            for try await text in speechRecognitionUseCase.startRecording() {
                                await send(.transcriptionUpdated(text))
                            }
                            await send(.recordingFinished)
                        } catch {
                            await send(.speechFailed)
                        }
                    }
                    .cancellable(id: CancelID.recording)
                }

            case let .transcriptionUpdated(text):
                state.text = text
                return .none

            case .recordingFinished:
                state.isRecording = false
                return .none

            case .speechFailed:
                state.isRecording = false
                state.errorAlert = .init(error: .speechFailure)
                return .none

            case .settingsButtonTapped:
                state.isSettingsPresented = true
                return .none

            case .settingsDismissed:
                state.isSettingsPresented = false
                return .none

            case .savedSummaryDismissed:
                state.savedSummary = nil
                return .none

            case .openSavedEventTapped:
                guard let startDate = state.savedSummary?.startDate else { return .none }
                state.savedSummary = nil
                return .run { _ in
                    let reference = Int(startDate.timeIntervalSinceReferenceDate)
                    await MainActor.run {
                        if let url = URL(string: "calshow:\(reference)") {
                            UIApplication.shared.open(url)
                        }
                    }
                }

            case .errorDismissed:
                state.errorAlert = nil
                return .none

            case .errorPrimaryActionTapped:
                let error = state.errorAlert?.error
                state.errorAlert = nil
                switch error {
                case .calendarSaveFailure:
                    state.isSettingsPresented = true
                    return .none
                case .calendarPermission, .speechFailure:
                    return .send(.openSettings)
                default:
                    return .none
                }

            case .openSettings:
                return .run { _ in
                    await MainActor.run {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
        }
        .ifLet(\.$confirmation, action: \.confirmation) {
            ConfirmScheduleFeature()
        }
    }
}

private func formatSummary(_ schedule: ParsedSchedule) -> String {
    if schedule.time.isEmpty {
        return schedule.date.isEmpty ? "날짜 미지정" : "\(schedule.date) (종일)"
    }
    return "\(schedule.date) \(schedule.time)"
}
