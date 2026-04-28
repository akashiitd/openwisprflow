import Foundation

enum CodingSpeechFormatter {
    private static let phraseReplacements: [(String, String)] = [
        ("new paragraph", "\n\n"),
        ("new line", "\n"),
        ("newline", "\n"),
        ("line break", "\n"),
        ("tab key", "\t"),
        ("tab", "\t"),
        ("open parenthesis", "("),
        ("open paren", "("),
        ("left paren", "("),
        ("close parenthesis", ")"),
        ("close paren", ")"),
        ("right paren", ")"),
        ("open bracket", "["),
        ("left bracket", "["),
        ("close bracket", "]"),
        ("right bracket", "]"),
        ("open brace", "{"),
        ("left brace", "{"),
        ("close brace", "}"),
        ("right brace", "}"),
        ("double quote", "\""),
        ("single quote", "'"),
        ("back tick", "`"),
        ("backtick", "`"),
        ("colon", ":"),
        ("semicolon", ";"),
        ("comma", ","),
        ("dot", "."),
        ("period", "."),
        ("underscore", "_"),
        ("dash", "-"),
        ("hyphen", "-"),
        ("slash", "/"),
        ("backslash", "\\"),
        ("equals", "="),
        ("equal sign", "="),
        ("plus", "+"),
        ("minus", "-"),
        ("asterisk", "*"),
        ("star", "*"),
        ("less than", "<"),
        ("greater than", ">"),
        ("arrow", "->"),
        ("fat arrow", "=>"),
        ("pipe", "|"),
        ("ampersand", "&")
    ]

    static func format(_ text: String, enabled: Bool) -> String {
        guard enabled else { return text.trimmingCharacters(in: .whitespacesAndNewlines) }

        var output = text
        for (phrase, replacement) in phraseReplacements {
            output = output.replacingWholePhrase(phrase, with: replacement)
        }

        output = output.replacingOccurrences(of: #" *\n *"#, with: "\n", options: .regularExpression)
        output = output.replacingOccurrences(of: #"\s+([,.;:\)\]\}])"#, with: "$1", options: .regularExpression)
        output = output.replacingOccurrences(of: #"([\(\[\{])\s+"#, with: "$1", options: .regularExpression)
        output = output.replacingOccurrences(of: #"\s+([=+\-*/<>|&])\s+"#, with: " $1 ", options: .regularExpression)
        output = output.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    func replacingWholePhrase(_ phrase: String, with replacement: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: phrase)
        let pattern = #"(?i)(?<![A-Za-z0-9_])"# + escaped + #"(?![A-Za-z0-9_])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return self }
        let range = NSRange(startIndex..<endIndex, in: self)
        let template = NSRegularExpression.escapedTemplate(for: replacement)
        return regex.stringByReplacingMatches(in: self, range: range, withTemplate: template)
    }
}
