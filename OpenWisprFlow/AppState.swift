import Foundation

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var transcript = ""
    @Published var status = "Ready"
    @Published var isRecording = false

    @Published var autoPaste: Bool { didSet { save(autoPaste, "autoPaste") } }
    @Published var formatForCode: Bool { didSet { save(formatForCode, "formatForCode") } }
    @Published var removeFillers: Bool { didSet { save(removeFillers, "removeFillers") } }
    @Published var formatLists: Bool { didSet { save(formatLists, "formatLists") } }
    @Published var pushToTalk: Bool { didSet { save(pushToTalk, "pushToTalk") } }
    @Published var recognitionLocale: String { didSet { save(recognitionLocale, "recognitionLocale") } }
    @Published var personalDictionary: [String] { didSet { save(personalDictionary, "personalDictionary") } }
    @Published var snippets: [String: String] { didSet { save(snippets, "snippets") } }

    @Published var useAICleanup: Bool { didSet { save(useAICleanup, "useAICleanup") } }
    @Published var apiKey: String { didSet { save(apiKey, "apiKey") } }
    @Published var apiEndpoint: String { didSet { save(apiEndpoint, "apiEndpoint") } }
    @Published var model: String { didSet { save(model, "model") } }
    @Published var tone: String { didSet { save(tone, "tone") } }

    private let dictationService = SpeechDictationService()

    private init() {
        let d = UserDefaults.standard
        // Defaults on first launch
        for (k, v) in [
            "autoPaste": true, "formatForCode": true,
            "removeFillers": true, "formatLists": true, "pushToTalk": false,
            "useAICleanup": false
        ] where d.object(forKey: k) == nil {
            d.set(v, forKey: k)
        }

        autoPaste = d.bool(forKey: "autoPaste")
        formatForCode = d.bool(forKey: "formatForCode")
        removeFillers = d.bool(forKey: "removeFillers")
        formatLists = d.bool(forKey: "formatLists")
        pushToTalk = d.bool(forKey: "pushToTalk")
        recognitionLocale = d.string(forKey: "recognitionLocale") ?? ""
        personalDictionary = d.stringArray(forKey: "personalDictionary") ?? []
        snippets = (d.dictionary(forKey: "snippets") as? [String: String]) ?? [:]

        useAICleanup = d.bool(forKey: "useAICleanup")
        apiKey = d.string(forKey: "apiKey") ?? ""
        apiEndpoint = d.string(forKey: "apiEndpoint") ?? "https://api.anthropic.com/v1/messages"
        model = d.string(forKey: "model") ?? "claude-opus-4-8"
        tone = d.string(forKey: "tone") ?? "default"
    }

    private func save(_ value: Any, _ key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    private var formatOptions: FormatOptions {
        FormatOptions(
            removeFillers: removeFillers,
            formatForCode: formatForCode,
            formatLists: formatLists,
            snippets: snippets,
            dictionary: personalDictionary
        )
    }

    // MARK: - Hotkey / UI entry points

    func toggleFromHotKey() {
        Task { await toggleDictation(shouldPasteWhenFinished: autoPaste) }
    }

    func hotKeyPressed() {
        guard pushToTalk else { toggleFromHotKey(); return }
        guard !isRecording else { return }
        Task { await start() }
    }

    func hotKeyReleased() {
        guard pushToTalk, isRecording else { return }
        Task { await stop(shouldPaste: autoPaste) }
    }

    func toggleFromUI() {
        Task { await toggleDictation(shouldPasteWhenFinished: false) }
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
            try await dictationService.start(
                options: formatOptions,
                locale: recognitionLocale,
                dictionary: personalDictionary
            ) { [weak self] text in
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
            var finalText = try await dictationService.stop()

            if useAICleanup, !apiKey.isEmpty {
                status = "Polishing…"
                finalText = await LLMRewriter.rewrite(
                    finalText, endpoint: apiEndpoint, apiKey: apiKey, model: model, tone: tone
                )
            }

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
