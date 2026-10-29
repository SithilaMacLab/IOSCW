import Foundation
import Testing
@testable import IosCW

@MainActor
final class FakeRateFetcher: RateTableFetching {
    var result: Result<RateTable, Error>
    private(set) var callCount = 0

    init(result: Result<RateTable, Error>) {
        self.result = result
    }

    func fetchTable() async throws -> RateTable {
        callCount += 1
        return try result.get()
    }
}

@MainActor
struct CurrencyTests {
    private let now = TestClock.date(2026, 10, 29)

    private func table(lkrPerUSD: Double = 300, fetchedAt: Date) -> RateTable {
        RateTable(base: "USD", rates: ["USD": 1, "LKR": lkrPerUSD, "EUR": 0.9, "GBP": 0.75], fetchedAt: fetchedAt)
    }

    private func service(fetcher: FakeRateFetcher, cache: RateCache) -> CachedExchangeRateService {
        let fixedNow = now
        return CachedExchangeRateService(fetcher: fetcher, cache: cache, maxAge: 12 * 3600, now: { fixedNow })
    }

    @Test("Rates are converted through the base currency")
    func conversionThroughBase() throws {
        let rates = table(fetchedAt: now)

        #expect(try CurrencyConverter.rateToLKR(for: "USD", in: rates) == 300)
        #expect(isClose(try CurrencyConverter.rateToLKR(for: "EUR", in: rates), 300 / 0.9))
        #expect(try CurrencyConverter.rateToLKR(for: "usd", in: rates) == 300)
        #expect(try CurrencyConverter.rateToLKR(for: "LKR", in: rates) == 1)
    }

    @Test("An unknown currency is refused")
    func unsupportedCurrency() {
        #expect(throws: ExchangeRateError.self) {
            try CurrencyConverter.rateToLKR(for: "XXX", in: table(fetchedAt: now))
        }
    }

    @Test("A table without LKR cannot be used")
    func tableWithoutLKR() {
        let broken = RateTable(base: "USD", rates: ["USD": 1, "EUR": 0.9], fetchedAt: now)
        #expect(throws: ExchangeRateError.self) {
            try CurrencyConverter.rateToLKR(for: "EUR", in: broken)
        }
    }

    @Test("The base currency needs no lookup")
    func baseCurrency() async throws {
        let fetcher = FakeRateFetcher(result: .failure(TestError()))
        let rate = try await service(fetcher: fetcher, cache: RateCache(defaults: isolatedDefaults())).rate(for: "LKR")

        #expect(rate.rateToLKR == 1)
        #expect(fetcher.callCount == 0)
    }

    @Test("With no cache the rate is fetched and then stored")
    func firstFetch() async throws {
        let cache = RateCache(defaults: isolatedDefaults())
        let fetcher = FakeRateFetcher(result: .success(table(fetchedAt: now)))

        let rate = try await service(fetcher: fetcher, cache: cache).rate(for: "USD")

        #expect(rate.rateToLKR == 300)
        #expect(rate.source == .live)
        #expect(fetcher.callCount == 1)
        #expect(cache.load()?.rates["LKR"] == 300)
    }

    @Test("A fresh cache is used without going online")
    func freshCache() async throws {
        let cache = RateCache(defaults: isolatedDefaults())
        let cachedAt = now.addingTimeInterval(-3600)
        cache.save(table(fetchedAt: cachedAt))
        let fetcher = FakeRateFetcher(result: .failure(TestError()))

        let rate = try await service(fetcher: fetcher, cache: cache).rate(for: "USD")

        #expect(rate.rateToLKR == 300)
        #expect(rate.source == .live)
        #expect(rate.asOf == cachedAt)
        #expect(fetcher.callCount == 0)
    }

    @Test("A stale cache is refreshed when online")
    func staleCacheRefreshed() async throws {
        let cache = RateCache(defaults: isolatedDefaults())
        cache.save(table(lkrPerUSD: 290, fetchedAt: now.addingTimeInterval(-13 * 3600)))
        let fetcher = FakeRateFetcher(result: .success(table(lkrPerUSD: 305, fetchedAt: now)))

        let rate = try await service(fetcher: fetcher, cache: cache).rate(for: "USD")

        #expect(rate.rateToLKR == 305)
        #expect(fetcher.callCount == 1)
        #expect(cache.load()?.rates["LKR"] == 305)
    }

    @Test("The last known rate is used when offline")
    func staleCacheUsedOffline() async throws {
        let cache = RateCache(defaults: isolatedDefaults())
        let cachedAt = now.addingTimeInterval(-48 * 3600)
        cache.save(table(lkrPerUSD: 290, fetchedAt: cachedAt))
        let fetcher = FakeRateFetcher(result: .failure(TestError()))

        let rate = try await service(fetcher: fetcher, cache: cache).rate(for: "USD")

        #expect(rate.rateToLKR == 290)
        #expect(rate.source == .cached)
        #expect(rate.asOf == cachedAt)
    }

    @Test("Offline with no cache there is no rate")
    func nothingAvailable() async {
        let fetcher = FakeRateFetcher(result: .failure(TestError()))
        let subject = service(fetcher: fetcher, cache: RateCache(defaults: isolatedDefaults()))

        await #expect(throws: ExchangeRateError.self) {
            try await subject.rate(for: "USD")
        }
    }

    @Test("The static service used in previews knows a few currencies")
    func staticService() async throws {
        let rates = StaticExchangeRateService()

        #expect(try await rates.rate(for: "USD").rateToLKR == 300)
        await #expect(throws: ExchangeRateError.self) {
            try await rates.rate(for: "XXX")
        }
    }
}
