import ComposableArchitecture
import Testing
@testable import SayCal

@MainActor
struct OnboardingFeatureTests {

    @Test func welcomeAdvancesToPermissions() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }
        await store.send(.primaryTapped) {
            $0.step = .permissions
        }
    }

    @Test func permissionsRequestsAllThreeAndAdvances() async {
        let store = TestStore(
            initialState: OnboardingFeature.State(step: .permissions)
        ) {
            OnboardingFeature()
        } withDependencies: {
            $0.requestPermissionsUseCase.requestCalendar = { true }
            $0.requestPermissionsUseCase.requestSpeech = { true }
            $0.requestPermissionsUseCase.requestMicrophone = { false }
        }

        await store.send(.primaryTapped) {
            $0.isRequesting = true
        }
        await store.receive(\.permissionsResult) {
            $0.isRequesting = false
            $0.hasRequestedPermissions = true
            $0.isCalendarGranted = true
            $0.isSpeechGranted = true
            $0.isMicGranted = false
            $0.step = .examples
        }
    }

    @Test func permissionsTappedAgainAfterRequestSkipsToExamples() async {
        let store = TestStore(
            initialState: OnboardingFeature.State(
                step: .permissions,
                isCalendarGranted: true,
                isSpeechGranted: true,
                isMicGranted: true,
                hasRequestedPermissions: true
            )
        ) {
            OnboardingFeature()
        }

        await store.send(.primaryTapped) {
            $0.step = .examples
        }
    }

    @Test func examplesPrimaryCompletesOnboarding() async {
        let store = TestStore(
            initialState: OnboardingFeature.State(step: .examples)
        ) {
            OnboardingFeature()
        }

        await store.send(.primaryTapped) {
            $0.isCompleted = true
        }
    }

    @Test func skipFromWelcomeCompletes() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }
        await store.send(.skipTapped) {
            $0.isCompleted = true
        }
    }

    @Test func skipFromPermissionsCompletes() async {
        let store = TestStore(
            initialState: OnboardingFeature.State(step: .permissions)
        ) {
            OnboardingFeature()
        }
        await store.send(.skipTapped) {
            $0.isCompleted = true
        }
    }

    @Test func backFromPermissionsReturnsToWelcome() async {
        let store = TestStore(
            initialState: OnboardingFeature.State(step: .permissions)
        ) {
            OnboardingFeature()
        }
        await store.send(.backTapped) {
            $0.step = .welcome
        }
    }

    @Test func backFromExamplesReturnsToPermissions() async {
        let store = TestStore(
            initialState: OnboardingFeature.State(step: .examples)
        ) {
            OnboardingFeature()
        }
        await store.send(.backTapped) {
            $0.step = .permissions
        }
    }

    @Test func backOnWelcomeIsNoop() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }
        await store.send(.backTapped)
    }
}
