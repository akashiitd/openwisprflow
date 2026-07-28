import Foundation

enum SnippetStore {
    static func expand(_ text: String, snippets: [String: String]) -> String {
        guard !snippets.isEmpty else { return text }
        var out = text
        // Longest triggers first so multi-word triggers win over their prefixes.
        for trigger in snippets.keys.sorted(by: { $0.count > $1.count }) {
            guard let expansion = snippets[trigger], !trigger.isEmpty else { continue }
            out = out.replacingWholePhrase(trigger, with: expansion)
        }
        return out
    }
}
