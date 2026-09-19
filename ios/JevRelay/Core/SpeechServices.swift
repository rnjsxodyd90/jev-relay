import AVFoundation
import Combine
import Speech
import UIKit

@MainActor
final class SpeechCapture: NSObject, ObservableObject {
    enum CaptureError: LocalizedError {
        case speechDenied, microphoneDenied, recognizerUnavailable, onDeviceUnavailable, audioFailure
        var errorDescription: String? {
            switch self {
            case .speechDenied: return "Speech recognition permission is required to record. Text input still works."
            case .microphoneDenied: return "Microphone permission is required to record. Text input still works."
            case .recognizerUnavailable: return "English speech recognition is currently unavailable. Text input still works."
            case .onDeviceUnavailable: return "On-device English recognition is not available on this device. Audio will not be sent to a remote fallback."
            case .audioFailure: return "Recording could not start. Text input still works."
            }
        }
    }

    typealias SpeechAuthorizationProvider = () async -> SFSpeechRecognizerAuthorizationStatus
    typealias MicrophoneAuthorizationProvider = () async -> Bool
    typealias ApplicationActiveProvider = @MainActor () -> Bool

    @Published private(set) var isRecording = false
    @Published private(set) var isStarting = false
    @Published private(set) var status = ""
    private let recognizer: SFSpeechRecognizer?
    private let engine = AVAudioEngine()
    private let speechAuthorizationProvider: SpeechAuthorizationProvider
    private let microphoneAuthorizationProvider: MicrophoneAuthorizationProvider
    private let isApplicationActive: ApplicationActiveProvider
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var timeoutTask: Task<Void, Never>?
    private var hasTap = false
    private var generation: UInt = 0
    var onTranscript: ((String) -> Void)?

    init(
        recognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
        speechAuthorizationProvider: @escaping SpeechAuthorizationProvider = SpeechCapture.requestSpeechAuthorization,
        microphoneAuthorizationProvider: @escaping MicrophoneAuthorizationProvider = SpeechCapture.requestMicrophoneAuthorization,
        isApplicationActive: @escaping ApplicationActiveProvider = { UIApplication.shared.applicationState == .active }
    ) {
        self.recognizer = recognizer
        self.speechAuthorizationProvider = speechAuthorizationProvider
        self.microphoneAuthorizationProvider = microphoneAuthorizationProvider
        self.isApplicationActive = isApplicationActive
        super.init()
    }

    func toggle() async {
        if isRecording || isStarting {
            stop()
            return
        }
        guard isApplicationActive() else {
            status = "Recording is unavailable while the app is not active."
            return
        }

        generation &+= 1
        let startGeneration = generation
        isStarting = true
        status = "Preparing on-device recording…"
        defer {
            if generation == startGeneration { isStarting = false }
        }

        do {
            let speechStatus = await speechAuthorizationProvider()
            guard canContinue(startGeneration) else { return }
            guard speechStatus == .authorized else { throw CaptureError.speechDenied }

            let microphoneGranted = await microphoneAuthorizationProvider()
            guard canContinue(startGeneration) else { return }
            guard microphoneGranted else { throw CaptureError.microphoneDenied }
            guard let recognizer, recognizer.isAvailable else { throw CaptureError.recognizerUnavailable }
            guard recognizer.supportsOnDeviceRecognition else { throw CaptureError.onDeviceUnavailable }
            guard canContinue(startGeneration) else { return }

            try activateAudio(recognizer: recognizer, generation: startGeneration)
        } catch {
            guard generation == startGeneration else { return }
            status = error.localizedDescription
            cleanupAudio()
            isStarting = false
        }
    }

    private func activateAudio(recognizer: SFSpeechRecognizer, generation startGeneration: UInt) throws {
        guard canContinue(startGeneration) else { return }
        cleanupAudio()
        guard canContinue(startGeneration) else { return }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        guard canContinue(startGeneration) else { return }
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        guard canContinue(startGeneration) else { cleanupAudio(); return }

        let speechRequest = SFSpeechAudioBufferRecognitionRequest()
        speechRequest.requiresOnDeviceRecognition = true
        speechRequest.shouldReportPartialResults = true
        request = speechRequest
        let node = engine.inputNode
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak speechRequest] buffer, _ in speechRequest?.append(buffer) }
        hasTap = true
        engine.prepare()
        do { try engine.start() }
        catch { cleanupAudio(); throw CaptureError.audioFailure }
        guard canContinue(startGeneration) else { cleanupAudio(); return }

        isStarting = false
        isRecording = true
        status = "Listening on device. Recording stops after 30 seconds."
        task = recognizer.recognitionTask(with: speechRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self, self.generation == startGeneration, self.isRecording else { return }
                if let result { self.onTranscript?(result.bestTranscription.formattedString) }
                if result?.isFinal == true || error != nil { self.stop() }
            }
        }
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.generation == startGeneration, self.isRecording else { return }
                self.status = "Recording stopped at 30 seconds."
                self.stop(keepStatus: true)
            }
        }
    }

    func stop(keepStatus: Bool = false) {
        generation &+= 1
        let wasActive = isRecording || isStarting
        cleanupAudio()
        isStarting = false
        isRecording = false
        if !keepStatus && wasActive { status = "Recording stopped. Review the editable text before interpreting." }
    }

    private func canContinue(_ expectedGeneration: UInt) -> Bool {
        generation == expectedGeneration && isStarting && isApplicationActive() && !Task.isCancelled
    }

    private func cleanupAudio() {
        timeoutTask?.cancel(); timeoutTask = nil
        task?.cancel(); task = nil
        request?.endAudio(); request = nil
        if engine.isRunning { engine.stop() }
        if hasTap { engine.inputNode.removeTap(onBus: 0); hasTap = false }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        if SFSpeechRecognizer.authorizationStatus() != .notDetermined { return SFSpeechRecognizer.authorizationStatus() }
        return await withCheckedContinuation { continuation in SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) } }
    }

    private static func requestMicrophoneAuthorization() async -> Bool {
        let permission = AVAudioApplication.shared.recordPermission
        if permission == .granted { return true }
        if permission == .denied { return false }
        return await withCheckedContinuation { continuation in AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) } }
    }
}

@MainActor
final class DutchSpeaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var isSpeaking = false
    @Published private(set) var availabilityMessage: String?
    private(set) var stopInvocationCount = 0
    private(set) var speakInvocationCount = 0
    private let synthesizer = AVSpeechSynthesizer()
    private(set) var voice: AVSpeechSynthesisVoice?

    override init() {
        super.init(); synthesizer.delegate = self
        voice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language == "nl-NL" })
            ?? AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language == "nl-BE" })
        if voice == nil { availabilityMessage = "No Dutch system voice is installed. Playback is unavailable; no English fallback will be used." }
    }

    func speak(_ text: String) {
        speakInvocationCount += 1
        stop()
        guard let voice, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text); utterance.voice = voice; utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance); isSpeaking = true
    }
    func stop() { stopInvocationCount += 1; if synthesizer.isSpeaking || synthesizer.isPaused { synthesizer.stopSpeaking(at: .immediate) }; isSpeaking = false }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { Task { @MainActor in self.isSpeaking = false } }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) { Task { @MainActor in self.isSpeaking = false } }
}
