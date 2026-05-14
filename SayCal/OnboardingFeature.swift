import ComposableArchitecture
import Foundation

let hasCompletedOnboardingKey = "hasCompletedOnboarding"

@Reducer
struct OnboardingFeature {
    @ObservableState
    struct State: Equatable {
        var step: Step = .welcome
        var isRequesting = false
        var isCalendarGranted = false
        var isSpeechGranted = false
        var isMicGranted = false
        var hasRequestedPermissions = false
        var isCompleted = false

        enum Step: Equatable {
            case welcome
            case permissions
            case examples
        }
    }

    enum Action {
        case primaryTapped
        case backTapped
        case skipTapped
        case permissionsResult(calendar: Bool, speech: Bool, mic: Bool)
    }

    @Dependency(\.requestPermissionsUseCase) var permissions

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .primaryTapped:
                switch state.step {
                case .welcome:
                    state.step = .permissions
                    return .none

                case .permissions:
                    if state.hasRequestedPermissions {
                        state.step = .examples
                        return .none
                    }
                    state.isRequesting = true
                    return .run { send in
                        async let calendar = permissions.requestCalendar()
                        async let speech = permissions.requestSpeech()
                        async let mic = permissions.requestMicrophone()
                        let results = await (calendar, speech, mic)
                        await send(.permissionsResult(
                            calendar: results.0,
                            speech: results.1,
                            mic: results.2
                        ))
                    }

                case .examples:
                    UserDefaults.standard.set(true, forKey: hasCompletedOnboardingKey)
                    state.isCompleted = true
                    return .none
                }

            case .backTapped:
                switch state.step {
                case .welcome:    return .none
                case .permissions: state.step = .welcome
                case .examples:    state.step = .permissions
                }
                return .none

            case .skipTapped:
                UserDefaults.standard.set(true, forKey: hasCompletedOnboardingKey)
                state.isCompleted = true
                return .none

            case let .permissionsResult(cal, speech, mic):
                state.isRequesting = false
                state.hasRequestedPermissions = true
                state.isCalendarGranted = cal
                state.isSpeechGranted = speech
                state.isMicGranted = mic
                state.step = .examples
                return .none
            }
        }
    }
}
