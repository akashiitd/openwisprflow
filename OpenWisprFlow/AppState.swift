import Foundation

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var transcript = ""
    @Published var status = "Ready"
    @Published var isRecording = false
    @Published var autoPaste: Bool {
        didSet { UserDefaults.standard.set(autoPaste, forKey: "autoPaste") }
    }
    @Published var formatForCode: Bool {
        didSet { UserDefaults.standard.set(formatForCode, forKey: "formatForCode") }
    }

    private let dictationService = SpeechDictationService()

    private init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "autoPaste") == nil {
            defaults.set(true, forKey: "autoPaste")
        }
        if defaults.object(forKey: "formatForCode") == nil {
            defaults.set(true, forKey: "formatForCode")
        }
        autoPaste = defaults.bool(forKey: "autoPaste")
        formatForCode = defaults.bool(forKey: "formatForCode")
    }

    func toggleFromHotKey() {
        Task {
            await toggleDictation(shouldPasteWhenFinished: autoPaste)
        }
    }

    func toggleFromUI() {
        Task {
            await toggleDictation(shouldPasteWhenFinished: false)
        }
    }

    func pasteTranscript() {
        guard !transcript.isEmpty else { return }
        TextInjector.paste(transcript)
        status = TextInjector.hasAccessibilityTrust ? "Pasted" : "Copied; enable Accessibility to auto-paste"
    }

    func copyTranscript() {
        guard !transcript.isEmpty else { return }
        TextInjector.copy(transcript)
        status = "Copied"
    }

    private func toggleDictation(shouldPasteWhenFinished: Bool) async {
        isRecording ? await stop(shouldPaste: shouldPasteWhenFinished) : await start()
    }

    private func start() async {
        do {
            transcript = ""
            status = "Listening"
            isRecording = true
            try await dictationService.start(formatForCode: formatForCode) { [weak self] text in
                self?.transcript = text
            }
        } catch {
            isRecording = false
            status = error.localizedDescription
        }
    }

    private func stop(shouldPaste: Bool) async {
        do {
            status = "Finishing"
            let finalText = try await dictationService.stop()
            transcript = finalText
            isRecording = false
            status = "Ready"

            if shouldPaste {
                TextInjector.paste(finalText)
                status = TextInjector.hasAccessibilityTrust ? "Pasted" : "Copied; enable Accessibility to auto-paste"
            }
        } catch {
            isRecording = false
            status = error.localizedDescription
        }
    }
}
