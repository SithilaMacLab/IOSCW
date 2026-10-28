import Foundation

enum RegexHelper {
    static func matches(_ pattern: String, in text: String, caseInsensitive: Bool = true) -> [[String]] {
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).map { match in
            (0..<match.numberOfRanges).map { index -> String in
                guard let captured = Range(match.range(at: index), in: text) else { return "" }
                return String(text[captured])
            }
        }
    }

    static func contains(_ pattern: String, in text: String) -> Bool {
        !matches(pattern, in: text).isEmpty
    }
}
