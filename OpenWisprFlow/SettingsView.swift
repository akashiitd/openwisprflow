import SwiftUI
import Speech

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("Dictation") {
                Toggle("Remove filler words (um, uh, like)", isOn: $appState.removeFillers)
                Toggle("Code phrases (symbols)", isOn: $appState.formatForCode)
                Toggle("Format spoken lists", isOn: $appState.formatLists)
                Toggle("Push-to-talk (hold hotkey)", isOn: $appState.pushToTalk)
                Toggle("Auto-paste from hotkey", isOn: $appState.autoPaste)
                Picker("Language", selection: $appState.recognitionLocale) {
                    Text("System default").tag("")
                    ForEach(sortedLocales, id: \.self) { id in
                        Text(Locale.current.localizedString(forIdentifier: id) ?? id).tag(id)
                    }
                }
            }

            Section("Personal dictionary (one term per line)") {
                TextEditor(text: dictionaryBinding)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 80)
            }

            Section("Voice snippets (trigger = expansion, one per line)") {
                TextEditor(text: snippetsBinding)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 80)
            }

            Section("AI cleanup (optional)") {
                Toggle("Use AI cleanup", isOn: $appState.useAICleanup)
                SecureField("Anthropic API key", text: $appState.apiKey)
                TextField("Model", text: $appState.model)
                TextField("Endpoint", text: $appState.apiEndpoint)
                Picker("Tone", selection: $appState.tone) {
                    Text("Default").tag("default")
                    Text("Formal").tag("formal")
                    Text("Casual").tag("casual")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 620)
    }

    private var sortedLocales: [String] {
        SFSpeechRecognizer.supportedLocales().map(\.identifier).sorted()
    }

    // Dictionary <-> newline-joined text
    private var dictionaryBinding: Binding<String> {
        Binding(
            get: { appState.personalDictionary.joined(separator: "\n") },
            set: { appState.personalDictionary = $0.split(separator: "\n").map(String.init).filter { !$0.isEmpty } }
        )
    }

    // Snippets <-> "trigger = expansion" lines
    private var snippetsBinding: Binding<String> {
        Binding(
            get: {
                appState.snippets.map { "\($0.key) = \($0.value)" }.sorted().joined(separator: "\n")
            },
            set: { text in
                var result: [String: String] = [:]
                for line in text.split(separator: "\n") {
                    let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                    guard parts.count == 2 else { continue }
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    if !key.isEmpty && !value.isEmpty { result[key] = value }
                }
                appState.snippets = result
            }
        )
    }
}
