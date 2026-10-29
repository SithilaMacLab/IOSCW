import Foundation

struct CSVRow: Equatable {
    let date: Date
    let type: String
    let merchant: String
    let category: String
    let amount: Double
    let currencyCode: String
    let exchangeRate: Double
    let amountLKR: Double
    let note: String
    let place: String
}

extension CSVRow {
    init(_ expense: Expense) {
        self.init(date: expense.date,
                  type: expense.type.title,
                  merchant: expense.merchant,
                  category: expense.category?.name ?? "Uncategorised",
                  amount: expense.amount,
                  currencyCode: expense.currencyCode,
                  exchangeRate: expense.exchangeRate,
                  amountLKR: expense.amountLKR,
                  note: expense.note,
                  place: expense.place?.name ?? "")
    }
}

enum CSVExporter {
    static let header = ["Date", "Type", "Merchant", "Category", "Amount", "Currency",
                         "Exchange rate to LKR", "Amount (LKR)", "Note", "Place"]

    private static let lineBreak = "\r\n"

    static func make(_ rows: [CSVRow], calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"

        var lines = [header.joined(separator: ",")]
        for row in rows {
            let fields = [
                formatter.string(from: row.date),
                escape(row.type),
                escape(row.merchant),
                escape(row.category),
                number(row.amount, places: 2),
                escape(row.currencyCode),
                number(row.exchangeRate, places: 6),
                number(row.amountLKR, places: 2),
                escape(row.note),
                escape(row.place)
            ]
            lines.append(fields.joined(separator: ","))
        }
        return lines.joined(separator: lineBreak) + lineBreak
    }

    static func fileName(now: Date = Date(), calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return "Pocketlens-transactions-\(formatter.string(from: now)).csv"
    }

    static func escape(_ field: String) -> String {
        var text = field
        if let first = text.first, "=+-@\t\r".contains(first) {
            text = "'" + text
        }
        guard text.rangeOfCharacter(from: CharacterSet(charactersIn: ",\"\n\r")) != nil else {
            return text
        }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func number(_ value: Double, places: Int) -> String {
        String(format: "%.\(places)f", value)
    }
}
