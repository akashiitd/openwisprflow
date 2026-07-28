import Foundation

struct FormatOptions {
    var removeFillers: Bool
    var formatForCode: Bool
    var formatLists: Bool
    var snippets: [String: String]
    var dictionary: [String]
}

// Single ordered pipeline applied to every transcript update.
enum TranscriptFormatter {
    static func apply(_ text: String, _ options: FormatOptions) -> String {
        var out = text
        if options.removeFillers { out = FillerWordFilter.strip(out) }
        out = SnippetStore.expand(out, snippets: options.snippets)
        out = CodingSpeechFormatter.correctCasing(out, dictionary: options.dictionary)
        out = CodingSpeechFormatter.format(out, code: options.formatForCode, lists: options.formatLists)
        return out
    }
}

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

    // Case-correct known dictionary terms (e.g. "swift ui" heard lowercase -> "SwiftUI").
    static func correctCasing(_ text: String, dictionary: [String]) -> String {
        var out = text
        for term in dictionary where !term.isEmpty {
            out = out.replacingWholePhrase(term, with: term)
        }
        return out
    }

    static func format(_ text: String, code: Bool, lists: Bool) -> String {
        var output = text
        if lists { output = formatEnumerations(output) }
        guard code else { return output.trimmingCharacters(in: .whitespacesAndNewlines) }

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

    // "first do X second do Y" / "number one X number two Y" -> numbered lines.
    private static let ordinals = [
        "first", "second", "third", "fourth", "fifth",
        "sixth", "seventh", "eighth", "ninth", "tenth"
    ]
    private static let cardinals = [
        "one", "two", "three", "four", "five",
        "six", "seven", "eight", "nine", "ten"
    ]

    private static func formatEnumerations(_ text: String) -> String {
        var out = text
        for (index, word) in ordinals.enumerated() {
            let n = index + 1
            let prefix = n == 1 ? "" : "\n"
            out = out.replacingWholePhrase(word, with: "\(prefix)\(n). ")
        }
        for (index, word) in cardinals.enumerated() {
            let n = index + 1
            let prefix = n == 1 ? "" : "\n"
            out = out.replacingWholePhrase("number \(word)", with: "\(prefix)\(n). ")
        }
        // Tidy the spaces introduced right after each "N. ".
        out = out.replacingOccurrences(of: #"(\d+\. ) +"#, with: "$1", options: .regularExpression)
        return out
    }
}

extension String {
    func replacingWholePhrase(_ phrase: String, with replacement: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: phrase)
        let pattern = #"(?i)(?<![A-Za-z0-9_])"# + escaped + #"(?![A-Za-z0-9_])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return self }
        let range = NSRange(startIndex..<endIndex, in: self)
        let template = NSRegularExpression.escapedTemplate(for: replacement)
        return regex.stringByReplacingMatches(in: self, range: range, withTemplate: template)
    }
}
