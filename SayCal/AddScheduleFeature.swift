import ComposableArchitecture
import Foundation

struct ParsedSchedule: Equatable {
    var date: String
    var time: String
}

@Reducer
struct AddScheduleFeature {
    @ObservableState
    struct State: Equatable {
        var text = ""
        var isLoading = false
        var isRecording = false
    }

    enum Action {
        case textChanged(String)
        case addButtonTapped
        case micButtonTapped
        case transcriptionUpdated(String)
        case recordingFinished
        case parseResponse(Result<ParsedSchedule, Error>)
        case calendarEventResponse(Result<Void, Error>)
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
                    await send(.parseResponse(
                        Result { try await parseScheduleUseCase.execute(text) }
                    ))
                }

            case let .parseResponse(.success(schedule)):
                let title = state.text
                return .run { send in
                    await send(.calendarEventResponse(
                        Result { try await createCalendarEventUseCase.execute(title, schedule) }
                    ))
                }

            case .parseResponse(.failure):
                state.isLoading = false
                return .none

            case .calendarEventResponse:
                state.isLoading = false
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
                        } catch { }
                        await send(.recordingFinished)
                    }
                    .cancellable(id: CancelID.recording)
                }

            case let .transcriptionUpdated(text):
                state.text = text
                return .none

            case .recordingFinished:
                state.isRecording = false
                return .none
            }
        }
    }
}
