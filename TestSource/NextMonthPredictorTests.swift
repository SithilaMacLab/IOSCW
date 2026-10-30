import Foundation
import Testing
@testable import IosCW

@MainActor
struct PredictorModelTests {
    @Test("Each model turns a history into a next value")
    func models() {
        #expect(NextMonthPredictor.predict(.last, history: [1, 2, 3]) == 3)
        #expect(isClose(NextMonthPredictor.predict(.mean3, history: [1, 2, 3, 4]), 3))
        #expect(isClose(NextMonthPredictor.predict(.weighted3, history: [10, 20, 30]), 140.0 / 6))
        #expect(isClose(NextMonthPredictor.predict(.weighted3, history: [20, 30]), 26))
        #expect(isClose(NextMonthPredictor.predict(.smoothing, history: [10, 20, 30]), 22.5))
    }

    @Test("The trend line follows a rising series but is shrunk towards the average")
    func trend() {
        #expect(isClose(NextMonthPredictor.predict(.trend, history: [10, 20, 30, 40, 50, 60]), 63))
        #expect(isClose(NextMonthPredictor.predict(.trend, history: [5, 5, 5]), 5))
        #expect(isClose(NextMonthPredictor.predict(.trend, history: [10, 20]), 15))
    }

    @Test("A prediction is never negative")
    func neverNegative() {
        #expect(NextMonthPredictor.predict(.trend, history: [100, 60, 20, 0, 0, 0]) == 0)
        let value = NextMonthPredictor.fit([100, 60, 20, 0, 0, 0, 0]).value
        #expect(value >= 0)
    }

    @Test("An empty history predicts zero")
    func emptyHistory() {
        for model in PredictorModel.allCases {
            #expect(NextMonthPredictor.predict(model, history: []) == 0)
        }
    }

    @Test("Backtesting predicts each past month from the months before it")
    func backtests() {
        let perfect = NextMonthPredictor.backtest(.last, [100, 100, 100, 100, 100])
        #expect(perfect.error == 0)
        #expect(perfect.points == 2)

        let tooShort = NextMonthPredictor.backtest(.weighted3, [1, 2, 3])
        #expect(tooShort.error == nil)
        #expect(tooShort.points == 0)

        let allZero = NextMonthPredictor.backtest(.weighted3, [0, 0, 0, 0])
        #expect(allZero.error == nil)
        #expect(allZero.points == 1)

        let jump = NextMonthPredictor.backtest(.weighted3, [100, 100, 100, 200])
        #expect(jump.error == 0.5)
        #expect(jump.points == 1)
    }

    @Test("With 6 or more months the best method wins, here the trend line")
    func risingSeriesPicksTrend() throws {
        let series = (0..<8).map { 100.0 + 20.0 * Double($0) }

        let result = NextMonthPredictor.fit(series)
        let error = try #require(result.error)

        #expect(result.model == .trend)
        #expect(result.backtestPoints == 5)
        #expect(isClose(error, 0.058))
        #expect(isClose(result.value, 246))
        #expect(result.low < result.value)
        #expect(result.high > result.value)
    }

    @Test("A steady series keeps the default method")
    func steadySeriesKeepsDefault() {
        let result = NextMonthPredictor.fit([Double](repeating: 100, count: 7))

        #expect(result.model == .weighted3)
        #expect(result.error == 0)
        #expect(isClose(result.value, 100))
        #expect(isClose(result.low, 95))
        #expect(isClose(result.high, 105))
    }

    @Test("Under 6 months the methods do not compete")
    func shortHistoryDoesNotCompete() {
        let result = NextMonthPredictor.fit([100, 120, 140, 160, 180])

        #expect(result.model == .weighted3)
        #expect(result.error != nil)
        #expect(result.backtestPoints == 2)
    }

    @Test("With exactly 3 months there is no accuracy yet and the range is the recent minimum and maximum")
    func threeMonths() {
        let result = NextMonthPredictor.fit([100, 200, 300])

        #expect(result.model == .weighted3)
        #expect(result.error == nil)
        #expect(result.backtestPoints == 0)
        #expect(isClose(result.value, 1400.0 / 6))
        #expect(result.low == 100)
        #expect(result.high == 300)
    }

    @Test("The learning phase depends on how many months there are", arguments: [
        (3, LearningPhase.basic),
        (4, LearningPhase.early),
        (5, LearningPhase.early),
        (6, LearningPhase.learned),
        (12, LearningPhase.learned)
    ])
    func phases(months: Int, expected: LearningPhase) {
        #expect(LearningPhase(months: months) == expected)
    }
}

@MainActor
struct NextMonthTrainingTests {
    private let now = TestClock.date(2026, 11, 15)
    private let calendar = TestClock.calendar

    private func forecast(_ entries: [ForecastEntry], at date: Date? = nil) -> NextMonthForecast? {
        if case .ready(let result) = NextMonthPredictor.train(entries, now: date ?? now, calendar: calendar) {
            return result
        }
        return nil
    }

    @Test("Fewer than three months of spending is not enough")
    func notEnoughData() {
        let entries = monthlyEntries([100, 200], now: now)

        #expect(NextMonthPredictor.train(entries, now: now, calendar: calendar)
                == .notEnoughData(monthsWithData: 2, monthsNeeded: 3))
        #expect(NextMonthPredictor.train([], now: now, calendar: calendar)
                == .notEnoughData(monthsWithData: 0, monthsNeeded: 3))
    }

    @Test("Three months give a basic forecast for the following month")
    func basicForecast() throws {
        let entries = monthlyEntries([100, 200, 300], now: now)
            + monthlyEntries([1000, 1000, 1000], now: now, category: "salary", type: .income)

        let result = try #require(forecast(entries))

        #expect(result.month == TestClock.date(2026, 12, 1, hour: 0))
        #expect(result.monthsOfHistory == 3)
        #expect(result.phase == .basic)
        #expect(isClose(result.expenses.value, 1400.0 / 6))
        #expect(result.expenses.error == nil)
        #expect(result.expenses.model == nil)
        #expect(isClose(result.income.value, 1000))
        #expect(result.categories.count == 1)
        #expect(result.categories[0].lastMonth == 300)
        #expect(isClose(result.leftOver, 1000 - 1400.0 / 6))
    }

    @Test("The current month and future months are not part of the training data")
    func currentMonthIgnored() throws {
        let base = monthlyEntries([100, 200, 300], now: now)
        let extra = [forecastEntry(TestClock.date(2026, 11, 5), 99_999),
                     forecastEntry(TestClock.date(2026, 12, 5), 99_999)]

        let without = try #require(forecast(base))
        let with = try #require(forecast(base + extra))

        #expect(without.expenses.value == with.expenses.value)
    }

    @Test("Each category gets its own best method, and the total is their sum")
    func categoriesCompete() throws {
        let food = (0..<8).map { 100.0 + 20.0 * Double($0) }
        let entries = monthlyEntries(food, now: now, category: "food")
            + monthlyEntries([Double](repeating: 500, count: 8), now: now, category: "groceries")

        let result = try #require(forecast(entries))
        let totalError = try #require(result.expenses.error)

        #expect(result.phase == .learned)
        #expect(result.categories.map(\.id) == ["groceries", "food"])
        #expect(result.categories[0].forecast.model == .weighted3)
        #expect(result.categories[1].forecast.model == .trend)
        #expect(isClose(result.categories[1].forecast.value, 246))
        #expect(isClose(result.expenses.value, 746))
        #expect(isClose(totalError, 58.0 / 3500.0))
        #expect(result.expenses.backtestPoints == 5)
    }

    @Test("Tiny categories are left out")
    func tinyCategoriesHidden() throws {
        let entries = monthlyEntries([100, 200, 300], now: now)
            + monthlyEntries([0.4, 0.4, 0.4], now: now, category: "tiny")

        let result = try #require(forecast(entries))

        #expect(!result.categories.contains { $0.id == "tiny" })
    }

    @Test("The fingerprint changes when past months change, not when the current month does")
    func fingerprint() {
        let base = monthlyEntries([100, 200, 300], now: now)
        let original = NextMonthPredictor.fingerprint(base, now: now, calendar: calendar)

        let withCurrent = NextMonthPredictor.fingerprint(
            base + [forecastEntry(TestClock.date(2026, 11, 5), 500)], now: now, calendar: calendar)
        let edited = NextMonthPredictor.fingerprint(
            monthlyEntries([100, 200, 350], now: now), now: now, calendar: calendar)
        let nextMonth = NextMonthPredictor.fingerprint(base, now: TestClock.date(2026, 12, 15), calendar: calendar)

        #expect(withCurrent == original)
        #expect(edited != original)
        #expect(nextMonth != original)
    }
}
