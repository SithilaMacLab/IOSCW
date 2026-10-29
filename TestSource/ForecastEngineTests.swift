import Foundation
import Testing
@testable import IosCW

@MainActor
struct ForecastEngineTests {
    private let calendar = TestClock.calendar
    private let midMonth = TestClock.date(2026, 10, 15)

    private var history: [ForecastEntry] {
        [
            forecastEntry(TestClock.date(2026, 7, 1), 10_000, type: .income),
            forecastEntry(TestClock.date(2026, 7, 5), 1000),
            forecastEntry(TestClock.date(2026, 7, 20), 500),

            forecastEntry(TestClock.date(2026, 8, 1), 10_000, type: .income),
            forecastEntry(TestClock.date(2026, 8, 10), 1000),
            forecastEntry(TestClock.date(2026, 8, 20), 300, category: "fun"),
            forecastEntry(TestClock.date(2026, 8, 25), 1000),

            forecastEntry(TestClock.date(2026, 9, 1), 10_000, type: .income),
            forecastEntry(TestClock.date(2026, 9, 3), 2000),
            forecastEntry(TestClock.date(2026, 9, 28), 200),

            forecastEntry(TestClock.date(2026, 10, 1), 10_000, type: .income),
            forecastEntry(TestClock.date(2026, 10, 2), 600)
        ]
    }

    private func ready(_ entries: [ForecastEntry], now: Date) -> ForecastResult? {
        if case .ready(let result) = ForecastEngine.forecast(entries, now: now, calendar: calendar) {
            return result
        }
        return nil
    }

    @Test("Spending is this month so far plus a recency-weighted average of what usually follows")
    func expectedSpending() throws {
        let result = try #require(ready(history, now: midMonth))

        #expect(result.expenses.soFar == 600)
        #expect(isClose(result.expenses.expected, 600 + 3700.0 / 6))
        #expect(result.expenses.low == 800)
        #expect(result.expenses.high == 1900)
        #expect(isClose(result.expenses.remaining, 3700.0 / 6))
    }

    @Test("A salary already paid is not counted twice")
    func incomeIsNotDoubled() throws {
        let result = try #require(ready(history, now: midMonth))

        #expect(result.income.soFar == 10_000)
        #expect(result.income.expected == 10_000)
        #expect(result.income.low == 10_000)
        #expect(result.income.high == 10_000)
        #expect(isClose(result.leftOver, 10_000 - result.expenses.expected))
    }

    @Test("Categories are forecast separately and sorted by expected amount")
    func categoryForecasts() throws {
        let result = try #require(ready(history, now: midMonth))

        #expect(result.categories.map(\.id) == ["food", "fun"])
        #expect(isClose(result.categories[0].figure.expected, 600 + 3100.0 / 6))
        #expect(isClose(result.categories[1].figure.expected, 100))
        #expect(result.categories[1].figure.soFar == 0)
    }

    @Test("The last three months are listed oldest first")
    func historyTotals() throws {
        let result = try #require(ready(history, now: midMonth))

        #expect(result.history.map(\.month) == [TestClock.date(2026, 7, 1, hour: 0),
                                                TestClock.date(2026, 8, 1, hour: 0),
                                                TestClock.date(2026, 9, 1, hour: 0)])
        #expect(result.history.map(\.expenses) == [1500, 2300, 2200])
        #expect(result.history.map(\.income) == [10_000, 10_000, 10_000])
    }

    @Test("On the last day of the month the forecast equals what was recorded")
    func lastDayOfMonth() throws {
        let result = try #require(ready(history, now: TestClock.date(2026, 10, 31)))

        #expect(result.expenses.expected == result.expenses.soFar)
        #expect(result.expenses.remaining == 0)
        #expect(result.dayOfMonth == 31)
        #expect(result.daysInMonth == 31)
    }

    @Test("Early in the month most of the usual spending is still to come")
    func firstDayOfMonth() throws {
        let result = try #require(ready(history, now: TestClock.date(2026, 10, 1, hour: 18)))

        #expect(result.expenses.expected > result.expenses.soFar)
        #expect(result.expenses.expected > 1500)
    }

    @Test("Fewer than three months of spending gives a not-enough-data result")
    func notEnoughData() {
        let entries = [
            forecastEntry(TestClock.date(2026, 8, 10), 1000),
            forecastEntry(TestClock.date(2026, 9, 10), 1000)
        ]

        let outcome = ForecastEngine.forecast(entries, now: midMonth, calendar: calendar)

        #expect(outcome == .notEnoughData(monthsWithData: 2, monthsNeeded: 3))
    }

    @Test("A gap in the last three months means not enough data")
    func gapInHistory() {
        let entries = [
            forecastEntry(TestClock.date(2026, 6, 10), 1000),
            forecastEntry(TestClock.date(2026, 8, 10), 1000),
            forecastEntry(TestClock.date(2026, 9, 10), 1000)
        ]

        let outcome = ForecastEngine.forecast(entries, now: midMonth, calendar: calendar)

        #expect(outcome == .notEnoughData(monthsWithData: 2, monthsNeeded: 3))
    }

    @Test("Income alone does not count as history")
    func incomeOnlyHistory() {
        let entries = [
            forecastEntry(TestClock.date(2026, 7, 1), 10_000, type: .income),
            forecastEntry(TestClock.date(2026, 8, 1), 10_000, type: .income),
            forecastEntry(TestClock.date(2026, 9, 1), 10_000, type: .income),
            forecastEntry(TestClock.date(2026, 9, 5), 500)
        ]

        let outcome = ForecastEngine.forecast(entries, now: midMonth, calendar: calendar)

        #expect(outcome == .notEnoughData(monthsWithData: 1, monthsNeeded: 3))
    }

    @Test("No data at all")
    func noEntries() {
        #expect(ForecastEngine.forecast([], now: midMonth, calendar: calendar)
                == .notEnoughData(monthsWithData: 0, monthsNeeded: 3))
    }

    @Test("Progress and remaining are derived from the figures")
    func figureHelpers() {
        let figure = ForecastFigure(soFar: 50, expected: 200, low: 100, high: 300)
        let overspent = ForecastFigure(soFar: 250, expected: 200, low: 100, high: 300)
        let empty = ForecastFigure(soFar: 0, expected: 0, low: 0, high: 0)

        #expect(figure.progress == 0.25)
        #expect(figure.remaining == 150)
        #expect(overspent.progress == 1)
        #expect(empty.progress == 0)
    }
}
