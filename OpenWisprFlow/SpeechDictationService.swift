import AVFoundation
import Foundation
import Speech

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

        guard speechStatus == .authorized else {
            throw DictationServiceError.speechDenied
        }

        let microphoneGranted = await AVCaptureDevice.requestAccess(for: .audio)
        guard microphoneGranted else {
            throw DictationServiceError.microphoneDenied
        }
    }

    func start(formatForCode: Bool, onUpdate: @escaping @MainActor (String) -> Void) async throws {
        try await requestPermissions()

        let session = LegacySpeechSession()
        legacySession = session
        try session.start(formatForCode: formatForCode, onUpdate: onUpdate)
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

    func start(formatForCode: Bool, onUpdate: @escaping @MainActor (String) -> Void) throws {
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            throw DictationServiceError.recognizerUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.contextualStrings = [
            "SwiftUI",
            "Xcode",
            "TypeScript",
            "JavaScript",
            "OpenWisprFlow",
            "function",
            "variable",
            "constant",
            "async",
            "await"
        ]
        if #available(macOS 13.0, *) {
            request.addsPunctuation = true
        }

        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            request.append(buffer)
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let text = result?.bestTranscription.formattedString {
                let formatted = CodingSpeechFormatter.format(text, enabled: formatForCode)
                guard !formatted.isEmpty else { return }
                self.latestText = formatted
                Task { @MainActor in
                    onUpdate(formatted)
                }
            }

            if error != nil || result?.isFinal == true {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
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

private extension AVAudioPCMBuffer {
    func deepCopy() -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength) else {
            return nil
        }

        copy.frameLength = frameLength
        let sourceBuffers = UnsafeMutableAudioBufferListPointer(mutableAudioBufferList)
        let destinationBuffers = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)

        for index in 0..<sourceBuffers.count {
            guard let source = sourceBuffers[index].mData,
                  let destination = destinationBuffers[index].mData else {
                continue
            }

            memcpy(destination, source, Int(sourceBuffers[index].mDataByteSize))
            destinationBuffers[index].mDataByteSize = sourceBuffers[index].mDataByteSize
        }

        return copy
    }
}
