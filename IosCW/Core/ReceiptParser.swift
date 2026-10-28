import Foundation

struct ParsedField<Value> {
    var value: Value?
    var confidence: Double

    func isReliable(threshold: Double = ParsedReceipt.reliableThreshold) -> Bool {
        value != nil && confidence >= threshold
    }

    static var missing: ParsedField<Value> {
        ParsedField(value: nil, confidence: 0)
    }
}

struct ParsedReceipt {
    var merchant: ParsedField<String>
    var date: ParsedField<Date>
    var total: ParsedField<Double>
    var currencyCode: ParsedField<String>
    var headerText: String

    static let reliableThreshold = 0.6
}

enum ReceiptParser {
    static func parse(rows: [ReceiptRow], now: Date = Date(), calendar: Calendar = .current) -> ParsedReceipt {
        ParsedReceipt(
            merchant: merchant(in: rows),
            date: date(in: rows, now: now, calendar: calendar),
            total: total(in: rows),
            currencyCode: currency(in: rows),
            headerText: rows.prefix(4).map(\.text).joined(separator: " "))
    }

    private static func ocrFactor(_ row: ReceiptRow) -> Double {
        0.6 + 0.4 * min(max(row.confidence, 0), 1)
    }

    private static func collapse(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static let merchantRejects =
        #"\b(invoice|receipt|tax|vat|bill|tel|phone|hotline|cashier|order|table|reg|thank|welcome|date|time|customer|copy)\b|www\.|http|@"#

    static func merchant(in rows: [ReceiptRow]) -> ParsedField<String> {
        for (index, row) in rows.prefix(6).enumerated() {
            let cleaned = collapse(row.text).trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            guard isNameLike(cleaned) else { continue }
            let position = index < 3 ? 1.0 : 0.8
            return ParsedField(value: displayName(cleaned), confidence: ocrFactor(row) * position)
        }
        return .missing
    }

    private static func isNameLike(_ text: String) -> Bool {
        let letters = text.filter(\.isLetter).count
        let visible = text.filter { !$0.isWhitespace }.count
        guard letters >= 3, visible > 0, text.count <= 40 else { return false }
        guard Double(letters) / Double(visible) >= 0.6 else { return false }
        return !RegexHelper.contains(merchantRejects, in: text)
    }

    private static func displayName(_ text: String) -> String {
        text == text.uppercased() ? text.capitalized : text
    }

    private static let monthNumbers: [String: Int] = [
        "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
        "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12
    ]

    private static let monthWords = "(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)"
    private static let yearFirst = #"(?<!\d)(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?!\d)"#
    private static let dayFirst = #"(?<!\d)(\d{1,2})[-/.](\d{1,2})[-/.](\d{4}|\d{2})(?!\d)"#
    private static let dayMonthName = #"(?<!\d)(\d{1,2})(?:st|nd|rd|th)?[\s\-.,]*"# + monthWords + #"[a-z]*\.?[\s\-.,]*(\d{4}|\d{2})(?!\d)"#
    private static let monthNameDay = monthWords + #"[a-z]*\.?\s*(\d{1,2})(?:st|nd|rd|th)?,?\s*(\d{4})(?!\d)"#
    private static let dateRejects = #"\b(exp|expiry|expires|valid|best before|use by)\b"#

    static func date(in rows: [ReceiptRow], now: Date, calendar: Calendar) -> ParsedField<Date> {
        for row in rows {
            if RegexHelper.contains(dateRejects, in: row.text) { continue }
            guard let date = firstDate(in: row.text, now: now, calendar: calendar) else { continue }
            let hasKeyword = row.text.range(of: "date", options: .caseInsensitive) != nil
            return ParsedField(value: date, confidence: ocrFactor(row) * (hasKeyword ? 1.0 : 0.9))
        }
        return .missing
    }

    private static func firstDate(in text: String, now: Date, calendar: Calendar) -> Date? {
        for match in RegexHelper.matches(yearFirst, in: text) {
            if let year = Int(match[1]), let month = Int(match[2]), let day = Int(match[3]),
               let date = makeDate(year: year, month: month, day: day, now: now, calendar: calendar) {
                return date
            }
        }

        for match in RegexHelper.matches(dayFirst, in: text) {
            guard let first = Int(match[1]), let second = Int(match[2]), let year = Int(match[3]) else { continue }
            let day: Int
            let month: Int
            if first > 12 {
                day = first
                month = second
            } else if second > 12 {
                day = second
                month = first
            } else {
                day = first
                month = second
            }
            if let date = makeDate(year: year, month: month, day: day, now: now, calendar: calendar) {
                return date
            }
        }

        for match in RegexHelper.matches(dayMonthName, in: text) {
            if let day = Int(match[1]), let month = monthNumbers[match[2].lowercased()], let year = Int(match[3]),
               let date = makeDate(year: year, month: month, day: day, now: now, calendar: calendar) {
                return date
            }
        }

        for match in RegexHelper.matches(monthNameDay, in: text) {
            if let month = monthNumbers[match[1].lowercased()], let day = Int(match[2]), let year = Int(match[3]),
               let date = makeDate(year: year, month: month, day: day, now: now, calendar: calendar) {
                return date
            }
        }
        return nil
    }

    private static func makeDate(year: Int, month: Int, day: Int, now: Date, calendar: Calendar) -> Date? {
        let fullYear = year < 100 ? 2000 + year : year
        var parts = DateComponents()
        parts.year = fullYear
        parts.month = month
        parts.day = day
        parts.hour = 12
        guard let date = calendar.date(from: parts) else { return nil }

        let check = calendar.dateComponents([.year, .month, .day], from: date)
        guard check.year == fullYear, check.month == month, check.day == day else { return nil }

        guard let latest = calendar.date(byAdding: .day, value: 2, to: now),
              let earliest = calendar.date(byAdding: .year, value: -5, to: now) else { return nil }
        return (date >= earliest && date <= latest) ? date : nil
    }

    private static let amountPattern =
        #"(?<![\d.,])(?:\d{1,3}(?:,\d{3})+\.\d{1,2}|\d+\.\d{2}|\d{1,3}(?:\.\d{3})+,\d{2}|\d+,\d{2}(?!\d))(?![\d])"#
    private static let wholeNumberPattern =
        #"(?<![\d.,])(?:\d{1,3}(?:,\d{3})+|\d{3,7})(?![\d.,])"#

    private static let strongTotal =
        #"grand\s*total|total\s*(due|payable|amount)|amount\s*(due|payable)|net\s*(total|amount|payable)|balance\s*due"#
    private static let plainTotal = #"\btotal\b"#
    private static let weakTotal = #"\b(amount|payable|due)\b"#
    private static let totalExcluded =
        #"sub\s*-?\s*total|saving|discount|points|tender|cash|change|paid|card|visa|master|qty|quantity|\bitems?\b|total\s*(tax|vat)|(tax|vat)\s*total"#
    private static let fallbackExcluded =
        #"tel|phone|hotline|invoice|bill\s*no|receipt|date|card|visa|master|cash|tender|change|paid|account|ref"#

    static func total(in rows: [ReceiptRow]) -> ParsedField<Double> {
        var best: (tier: Int, index: Int, value: Double, factor: Double)?

        for (index, row) in rows.enumerated() {
            guard !RegexHelper.contains(totalExcluded, in: row.text) else { continue }
            let tier = totalTier(of: row.text)
            guard tier > 0 else { continue }

            var found = extractAmounts(in: row.text)
            if found.isEmpty, index + 1 < rows.count {
                let next = rows[index + 1].text
                if totalTier(of: next) == 0, !RegexHelper.contains(totalExcluded, in: next) {
                    found = extractAmounts(in: next)
                }
            }
            if found.isEmpty {
                found = extractWholeNumbers(in: row.text)
            }
            guard let value = found.last, value > 0 else { continue }

            if let current = best, (current.tier, current.index) > (tier, index) { continue }
            let factor: Double = tier == 3 ? 1.0 : (tier == 2 ? 0.95 : 0.7)
            best = (tier, index, value, factor)
        }

        if let best {
            return ParsedField(value: best.value, confidence: ocrFactor(rows[best.index]) * best.factor)
        }

        var largest: (value: Double, row: ReceiptRow)?
        for row in rows where !RegexHelper.contains(fallbackExcluded, in: row.text) {
            for value in extractAmounts(in: row.text) where value > (largest?.value ?? 0) {
                largest = (value, row)
            }
        }
        if let largest {
            return ParsedField(value: largest.value, confidence: ocrFactor(largest.row) * 0.45)
        }
        return .missing
    }

    private static func totalTier(of text: String) -> Int {
        if RegexHelper.contains(strongTotal, in: text) { return 3 }
        if RegexHelper.contains(plainTotal, in: text) { return 2 }
        if RegexHelper.contains(weakTotal, in: text) { return 1 }
        return 0
    }

    static func extractAmounts(in text: String) -> [Double] {
        RegexHelper.matches(amountPattern, in: text).compactMap { parseAmount($0[0]) }
    }

    private static func extractWholeNumbers(in text: String) -> [Double] {
        RegexHelper.matches(wholeNumberPattern, in: text).compactMap { parseAmount($0[0]) }
    }

    static func parseAmount(_ text: String) -> Double? {
        let lastDot = text.lastIndex(of: ".")
        let lastComma = text.lastIndex(of: ",")

        let normalized: String
        switch (lastDot, lastComma) {
        case let (dot?, comma?):
            normalized = dot > comma
                ? text.replacingOccurrences(of: ",", with: "")
                : text.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        case (nil, _?):
            let decimalComma = RegexHelper.contains(#"^\d+,\d{2}$"#, in: text)
            normalized = decimalComma
                ? text.replacingOccurrences(of: ",", with: ".")
                : text.replacingOccurrences(of: ",", with: "")
        default:
            normalized = text
        }

        guard let value = Double(normalized), value > 0, value < 100_000_000 else { return nil }
        return value
    }

    private static let currencyRules: [(code: String, explicit: String, symbol: String?)] = [
        ("LKR", #"(?<![a-z])(lkr|rs)(?![a-z])"#, "රු"),
        ("USD", #"(?<![a-z])(usd|us\$)(?![a-z])"#, #"\$"#),
        ("EUR", #"(?<![a-z])eur(?![a-z])"#, "€"),
        ("GBP", #"(?<![a-z])gbp(?![a-z])"#, "£"),
        ("INR", #"(?<![a-z])inr(?![a-z])"#, "₹"),
        ("AUD", #"(?<![a-z])aud(?![a-z])"#, nil),
        ("SGD", #"(?<![a-z])sgd(?![a-z])"#, nil),
        ("AED", #"(?<![a-z])aed(?![a-z])"#, nil),
        ("MYR", #"(?<![a-z])myr(?![a-z])"#, nil)
    ]

    static func currency(in rows: [ReceiptRow]) -> ParsedField<String> {
        let text = rows.map(\.text).joined(separator: "\n")

        var best: (code: String, score: Int, explicit: Int)?
        for rule in currencyRules {
            let explicit = RegexHelper.matches(rule.explicit, in: text).count
            let symbol = rule.symbol.map { RegexHelper.matches($0, in: text).count } ?? 0
            let score = explicit * 2 + symbol
            guard score > 0 else { continue }
            if best == nil || score > (best?.score ?? 0) {
                best = (rule.code, score, explicit)
            }
        }

        guard let best else {
            return ParsedField(value: AppConstants.baseCurrencyCode, confidence: 0.7)
        }
        return ParsedField(value: best.code, confidence: best.explicit > 0 ? 0.9 : 0.55)
    }
}
