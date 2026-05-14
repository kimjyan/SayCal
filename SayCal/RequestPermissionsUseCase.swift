import AVFoundation
import Dependencies
import EventKit
import Speech

struct RequestPermissionsUseCase: Sendable {
    var requestCalendar: @Sendable () async -> Bool
    var requestSpeech: @Sendable () async -> Bool
    var requestMicrophone: @Sendable () async -> Bool
}

extension RequestPermissionsUseCase: DependencyKey {
    static var liveValue: Self {
        .init(
            requestCalendar: {
                let store = EKEventStore()
                return (try? await store.requestFullAccessToEvents()) ?? false
            },
            requestSpeech: {
                await withCheckedContinuation { cont in
                    SFSpeechRecognizer.requestAuthorization { status in
                        cont.resume(returning: status == .authorized)
                    }
                }
            },
            requestMicrophone: {
                await withCheckedContinuation { cont in
                    AVAudioApplication.requestRecordPermission { granted in
                        cont.resume(returning: granted)
                    }
                }
            }
        )
    }
}

extension DependencyValues {
    var requestPermissionsUseCase: RequestPermissionsUseCase {
        get { self[RequestPermissionsUseCase.self] }
        set { self[RequestPermissionsUseCase.self] = newValue }
    }
}
