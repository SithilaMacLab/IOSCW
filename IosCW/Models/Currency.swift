import Foundation

struct Currency: Identifiable, Hashable {
    let code: String

    var id: String { code }

    var name: String {
        Locale.current.localizedString(forCurrencyCode: code) ?? code
    }

    static let supported: [Currency] = [
        "LKR", "USD", "EUR", "GBP", "AUD", "CAD", "SGD", "INR", "JPY", "AED",
        "CNY", "MYR", "THB", "CHF", "NZD", "SAR", "QAR", "KRW"
    ].map { Currency(code: $0) }
}
