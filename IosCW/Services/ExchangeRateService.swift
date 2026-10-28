import Foundation

protocol ExchangeRateServiceProtocol {
    func rate(for currencyCode: String) async throws -> ExchangeRate
}

protocol RateTableFetching {
    func fetchTable() async throws -> RateTable
}

struct ExchangeRateAPIFetcher: RateTableFetching {
    private struct Response: Decodable {
        let result: String
        let baseCode: String
        let rates: [String: Double]
    }

    func fetchTable() async throws -> RateTable {
        guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else {
            throw ExchangeRateError.unavailable
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw ExchangeRateError.unavailable
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(Response.self, from: data)
        guard decoded.result == "success" else {
            throw ExchangeRateError.unavailable
        }
        return RateTable(base: decoded.baseCode, rates: decoded.rates, fetchedAt: Date())
    }
}

final class RateCache {
    private let defaults: UserDefaults
    private let key = "exchangeRateTable"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> RateTable? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(RateTable.self, from: data)
    }

    func save(_ table: RateTable) {
        guard let data = try? JSONEncoder().encode(table) else { return }
        defaults.set(data, forKey: key)
    }
}

final class CachedExchangeRateService: ExchangeRateServiceProtocol {
    private let fetcher: RateTableFetching
    private let cache: RateCache
    private let maxAge: TimeInterval
    private let now: () -> Date

    init(fetcher: RateTableFetching = ExchangeRateAPIFetcher(),
         cache: RateCache = RateCache(),
         maxAge: TimeInterval = 12 * 60 * 60,
         now: @escaping () -> Date = Date.init) {
        self.fetcher = fetcher
        self.cache = cache
        self.maxAge = maxAge
        self.now = now
    }

    func rate(for currencyCode: String) async throws -> ExchangeRate {
        let code = currencyCode.uppercased()
        if code == AppConstants.baseCurrencyCode {
            return ExchangeRate(currencyCode: code, rateToLKR: 1, asOf: now(), source: .live)
        }

        let cached = cache.load()

        if let cached,
           now().timeIntervalSince(cached.fetchedAt) < maxAge,
           let rate = try? CurrencyConverter.rateToLKR(for: code, in: cached) {
            return ExchangeRate(currencyCode: code, rateToLKR: rate, asOf: cached.fetchedAt, source: .live)
        }

        let table: RateTable
        do {
            table = try await fetcher.fetchTable()
            cache.save(table)
        } catch {
            if let cached, let rate = try? CurrencyConverter.rateToLKR(for: code, in: cached) {
                return ExchangeRate(currencyCode: code, rateToLKR: rate, asOf: cached.fetchedAt, source: .cached)
            }
            throw ExchangeRateError.unavailable
        }

        let rate = try CurrencyConverter.rateToLKR(for: code, in: table)
        return ExchangeRate(currencyCode: code, rateToLKR: rate, asOf: table.fetchedAt, source: .live)
    }
}

struct StaticExchangeRateService: ExchangeRateServiceProtocol {
    var rates: [String: Double] = ["USD": 300, "EUR": 330, "GBP": 390, "AUD": 200]

    func rate(for currencyCode: String) async throws -> ExchangeRate {
        let code = currencyCode.uppercased()
        if code == AppConstants.baseCurrencyCode {
            return ExchangeRate(currencyCode: code, rateToLKR: 1, asOf: Date(), source: .live)
        }
        guard let rate = rates[code] else {
            throw ExchangeRateError.unsupportedCurrency(code)
        }
        return ExchangeRate(currencyCode: code, rateToLKR: rate, asOf: Date(), source: .live)
    }
}
