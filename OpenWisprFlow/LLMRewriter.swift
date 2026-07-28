import Foundation

// Optional cloud cleanup pass. No key configured -> returns input unchanged, no network.
// Any failure (network, decode, timeout) falls back to the input so paste is never blocked.
enum LLMRewriter {
    static func rewrite(_ text: String, endpoint: String, apiKey: String, model: String, tone: String) async -> String {
        guard !apiKey.isEmpty, !text.isEmpty, let url = URL(string: endpoint) else { return text }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": systemPrompt(tone: tone),
            "messages": [["role": "user", "content": text]]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return text }
        request.httpBody = data

        do {
            let (respData, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return text }
            // Response shape: { "content": [ { "type": "text", "text": "..." } ] }
            guard let json = try JSONSerialization.jsonObject(with: respData) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let out = content.first(where: { $0["type"] as? String == "text" })?["text"] as? String,
                  !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return text }
            return out.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return text
        }
    }

    private static func systemPrompt(tone: String) -> String {
        let base = "You clean up dictated speech-to-text. Fix obvious transcription errors and spoken self-corrections. Do not add content, do not answer questions, do not add commentary. Return only the cleaned text."
        switch tone {
        case "formal": return base + " Use a formal, professional tone."
        case "casual": return base + " Use a casual, conversational tone."
        default: return base + " Preserve the original tone."
        }
    }
}
