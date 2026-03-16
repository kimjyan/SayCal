import AVFoundation
import Dependencies
import Speech

struct SpeechRecognitionUseCase: Sendable {
    var startRecording: @Sendable () -> AsyncThrowingStream<String, Error>
}

extension SpeechRecognitionUseCase: DependencyKey {
    static var liveValue: Self {
        .init {
            AsyncThrowingStream { continuation in
                let engine = SpeechEngine()
                continuation.onTermination = { _ in engine.stop() }
                Task { await engine.start(continuation: continuation) }
            }
        }
    }
}

extension DependencyValues {
    var speechRecognitionUseCase: SpeechRecognitionUseCase {
        get { self[SpeechRecognitionUseCase.self] }
        set { self[SpeechRecognitionUseCase.self] = newValue }
    }
}

// MARK: - Private

private final class SpeechEngine: @unchecked Sendable {
    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
    }

    func start(continuation: AsyncThrowingStream<String, Error>.Continuation) async {
        guard let recognizer else {
            continuation.finish(throwing: SpeechError.recognizerUnavailable)
            return
        }

        let authStatus: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard authStatus == .authorized else {
            continuation.finish(throwing: SpeechError.notAuthorized)
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            continuation.finish(throwing: error)
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let inputNode = audioEngine.inputNode
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputNode.outputFormat(forBus: 0)) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            continuation.finish(throwing: error)
            return
        }

        task = recognizer.recognitionTask(with: request) { result, error in
            if let result {
                continuation.yield(result.bestTranscription.formattedString)
                if result.isFinal { continuation.finish() }
            } else if let error {
                continuation.finish(throwing: error)
            }
        }
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

enum SpeechError: LocalizedError {
    case recognizerUnavailable
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable: "음성 인식을 사용할 수 없습니다."
        case .notAuthorized: "음성 인식 권한이 필요합니다."
        }
    }
}
