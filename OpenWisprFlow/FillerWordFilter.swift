import Foundation

enum FillerWordFilter {
    // Multi-word phrases first so "you know" matches before "know" would.
    private static let fillers = [
        "you know", "i mean", "sort of", "kind of", "kinda", "sorta",
        "um", "uh", "erm", "er", "ah", "hmm", "like", "basically", "literally"
    ]

    static func strip(_ text: String) -> String {
        var out = text
        for filler in fillers {
            let escaped = NSRegularExpression.escapedPattern(for: filler)
            // Whole-phrase, case-insensitive, optionally followed by a comma.
            let pattern = #"(?i)(?<![A-Za-z0-9_])"# + escaped + #",?(?![A-Za-z0-9_])"#
            out = out.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        // Collapse the whitespace left behind, and stray leading punctuation.
        out = out.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
        out = out.replacingOccurrences(of: #" +([,.;:!?])"#, with: "$1", options: .regularExpression)
        out = out.replacingOccurrences(of: #"^[\s,]+"#, with: "", options: .regularExpression)
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#if DEBUG
extension FillerWordFilter {
    static func demo() {
        assert(strip("um so like the function") == "so the function", strip("um so like the function"))
        assert(strip("you know, this is basically fine") == "this is fine", strip("you know, this is basically fine"))
        assert(strip("keep this intact") == "keep this intact")
    }
}
#endif
