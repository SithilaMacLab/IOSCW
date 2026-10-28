import Foundation

struct RateTable: Codable, Equatable {
    let base: String
    let rates: [String: Double]
    let fetchedAt: Date
}

enum RateSource: Equatable {
    case live
    case cached
    case stored
}

struct ExchangeRate: Equatable {
    let currencyCode: String
    let rateToLKR: Double
    let asOf: Date
    let source: RateSource
}

enum ExchangeRateError: LocalizedError {
    case unsupportedCurrency(String)
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unsupportedCurrency(let code): "\(code) isn't supported."
        case .unavailable: "No exchange rate is available right now."
        }
    }
}

enum CurrencyConverter {
    static func rateToLKR(for code: String, in table: RateTable) throws -> Double {
        let upper = code.uppercased()
        if upper == AppConstants.baseCurrencyCode {
            return 1
        }
        guard let lkrPerBase = table.rates[AppConstants.baseCurrencyCode],
              let codePerBase = table.rates[upper],
              codePerBase > 0 else {
            throw ExchangeRateError.unsupportedCurrency(upper)
        }
        return lkrPerBase / codePerBase
    }
}
