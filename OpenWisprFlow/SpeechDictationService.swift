import AVFoundation
import Foundation
import Speech

private func log(_ message: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    fputs("[\(ts)] [OpenWisprFlow] \(message)\n", stderr)
}

enum DictationServiceError: LocalizedError {
    case microphoneDenied
    case speechDenied
    case recognizerUnavailable
    case noSpeechCaptured

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            "Microphone permission is required to dictate."
        case .speechDenied:
            "Speech recognition permission is required to transcribe."
        case .recognizerUnavailable:
            "Apple Speech recognition is not available for the current locale."
        case .noSpeechCaptured:
            "No speech was captured."
        }
    }
}

final class SpeechDictationService {
    private var legacySession: LegacySpeechSession?

    func requestPermissions() async throws {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        log("Speech authorization status: \(speechStatus.rawValue)")
        guard speechStatus == .authorized else {
            throw DictationServiceError.speechDenied
        }

        let microphoneGranted = await AVCaptureDevice.requestAccess(for: .audio)
        log("Microphone granted: \(microphoneGranted)")
        guard microphoneGranted else {
            throw DictationServiceError.microphoneDenied
        }
    }

    func start(
        options: FormatOptions,
        locale: String,
        dictionary: [String],
        onUpdate: @escaping @MainActor (String) -> Void
    ) async throws {
        try await requestPermissions()

        let session = LegacySpeechSession()
        legacySession = session
        try session.start(options: options, locale: locale, dictionary: dictionary, onUpdate: onUpdate)
    }

    func stop() async throws -> String {
        if let session = legacySession {
            legacySession = nil
            return try await session.stop()
        }

        return ""
    }
}

private final class LegacySpeechSession {
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var latestText = ""

    func start(
        options: FormatOptions,
        locale: String,
        dictionary: [String],
        onUpdate: @escaping @MainActor (String) -> Void
    ) throws {
        let recognizer = locale.isEmpty
            ? SFSpeechRecognizer()
            : SFSpeechRecognizer(locale: Locale(identifier: locale))
        guard let recognizer, recognizer.isAvailable else {
            log("SFSpeechRecognizer unavailable")
            throw DictationServiceError.recognizerUnavailable
        }
        log("SFSpeechRecognizer locale: \(recognizer.locale.identifier), available: \(recognizer.isAvailable)")

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        let builtInTerms = [
            "SwiftUI", "Xcode", "TypeScript", "JavaScript", "OpenWisprFlow",
            "function", "variable", "constant", "async", "await"
        ]
        request.contextualStrings = builtInTerms + dictionary.filter { !$0.isEmpty }
        if #available(macOS 13.0, *) {
            request.addsPunctuation = true
        }

        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        log("Audio input format: \(inputFormat)")
        log("Sample rate: \(inputFormat.sampleRate), channels: \(inputFormat.channelCount)")
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            request.append(buffer)
        }

        log("Starting recognition task...")
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let error = error {
                log("Recognition error: \(error.localizedDescription)")
            }

            if let text = result?.bestTranscription.formattedString {
                log("Got transcription: \(text)")
                let formatted = TranscriptFormatter.apply(text, options)
                guard !formatted.isEmpty else { return }
                self.latestText = formatted
                Task { @MainActor in
                    onUpdate(formatted)
                }
            } else if result == nil && error == nil {
                log("Recognition callback: no result, no error")
            }

            if let result = result {
                log("isFinal: \(result.isFinal)")
            }

            if error != nil || result?.isFinal == true {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        log("Audio engine started successfully")
    }

    func stop() async throws -> String {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        try? await Task.sleep(for: .milliseconds(250))

        guard !latestText.isEmpty else {
            throw DictationServiceError.noSpeechCaptured
        }
        return latestText
    }
}
