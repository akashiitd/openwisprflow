import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            TextEditor(text: $appState.transcript)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor))
                }
                .frame(minHeight: 180)

            controls
        }
        .padding(22)
        .frame(width: 520, height: 390)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(appState.isRecording ? Color.red : Color.green)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text("OpenWisprFlow")
                    .font(.title2.weight(.semibold))
                Text(appState.status)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("⌃⌥Space")
                .font(.system(.callout, design: .monospaced).weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack {
                Toggle("Code phrases", isOn: $appState.formatForCode)
                Toggle("Auto-paste from hotkey", isOn: $appState.autoPaste)
            }

            HStack(spacing: 10) {
                Button {
                    appState.toggleFromUI()
                } label: {
                    Label(appState.isRecording ? "Stop" : "Start", systemImage: appState.isRecording ? "stop.fill" : "mic.fill")
                        .frame(width: 112)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    appState.pasteTranscript()
                } label: {
                    Label("Paste", systemImage: "arrow.down.doc.fill")
                        .frame(width: 96)
                }
                .disabled(appState.transcript.isEmpty)

                Button {
                    appState.copyTranscript()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .frame(width: 90)
                }
                .disabled(appState.transcript.isEmpty)

                Spacer()
            }
        }
    }
}
