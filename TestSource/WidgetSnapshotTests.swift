import Foundation
import Testing
@testable import IosCW

@MainActor
struct WidgetSnapshotTests {
    private let calendar = TestClock.calendar
    private let now = TestClock.date(2026, 10, 15)

    private let budgets = [
        WidgetBudgetInput(categoryID: "groceries", name: "Groceries", colorHex: "#34C759", limit: 10_000),
        WidgetBudgetInput(categoryID: "food", name: "Food & Dining", colorHex: "#FF9500", limit: 5000)
    ]

    private var thisMonth: [ForecastEntry] {
        [
            forecastEntry(TestClock.date(2026, 10, 2), 1500, category: "groceries"),
            forecastEntry(TestClock.date(2026, 10, 9), 2500, category: "groceries"),
            forecastEntry(TestClock.date(2026, 10, 4), 4000, category: "food"),
            forecastEntry(TestClock.date(2026, 10, 6), 1000, category: "fun"),
            forecastEntry(TestClock.date(2026, 10, 1), 50_000, type: .income, category: "salary"),
            forecastEntry(TestClock.date(2026, 9, 20), 9999, category: "groceries")
        ]
    }

    @Test("Totals count only this month, and unbudgeted spending is kept out of the budget gauge")
    func totals() {
        let snapshot = WidgetSnapshotBuilder.make(entries: thisMonth, budgets: budgets, now: now, calendar: calendar)

        #expect(snapshot.spent == 9000)
        #expect(snapshot.income == 50_000)
        #expect(snapshot.totalLimit == 15_000)
        #expect(snapshot.budgetedSpent == 8000)
        #expect(isClose(snapshot.budgetProgress, 8000.0 / 15_000.0))
        #expect(snapshot.currencyCode == "LKR")
        #expect(snapshot.month == TestClock.date(2026, 10, 1, hour: 0))
    }

    @Test("Budget lines are sorted with the most used first")
    func lineOrder() {
        let snapshot = WidgetSnapshotBuilder.make(entries: thisMonth, budgets: budgets, now: now, calendar: calendar)

        #expect(snapshot.budgets.map(\.id) == ["food", "groceries"])
        #expect(isClose(snapshot.budgets[0].progress, 0.8))
        #expect(isClose(snapshot.budgets[1].progress, 0.4))
    }

    @Test("No expected spending is shown without enough history")
    func noForecastWithoutHistory() {
        let snapshot = WidgetSnapshotBuilder.make(entries: thisMonth, budgets: budgets, now: now, calendar: calendar)
        #expect(snapshot.expectedSpending == nil)
    }

    @Test("Expected spending is included once there are three months of history")
    func forecastWithHistory() {
        let history = [
            forecastEntry(TestClock.date(2026, 7, 5), 1000),
            forecastEntry(TestClock.date(2026, 8, 5), 1000),
            forecastEntry(TestClock.date(2026, 9, 5), 1000)
        ]

        let snapshot = WidgetSnapshotBuilder.make(entries: thisMonth + history, budgets: budgets, now: now, calendar: calendar)

        #expect(snapshot.expectedSpending != nil)
        #expect((snapshot.expectedSpending ?? 0) >= snapshot.spent)
    }

    @Test("Without budgets the gauge has nothing to show")
    func noBudgets() {
        let snapshot = WidgetSnapshotBuilder.make(entries: thisMonth, budgets: [], now: now, calendar: calendar)

        #expect(snapshot.budgets.isEmpty)
        #expect(snapshot.totalLimit == 0)
        #expect(snapshot.budgetProgress == 0)
        #expect(snapshot.spent == 9000)
    }

    @Test("Only the first few budget lines are kept")
    func lineLimit() {
        let many = (0..<10).map {
            WidgetBudgetInput(categoryID: "c\($0)", name: "Category \($0)", colorHex: "#000000", limit: 1000)
        }

        let snapshot = WidgetSnapshotBuilder.make(entries: [], budgets: many, now: now, calendar: calendar)

        #expect(snapshot.budgets.count == WidgetSnapshotBuilder.maxBudgetLines)
        #expect(snapshot.totalLimit == 10_000)
    }

    @Test("The summary survives being saved and loaded as JSON")
    func jsonRoundTrip() throws {
        let snapshot = WidgetSnapshotBuilder.make(entries: thisMonth, budgets: budgets, now: now, calendar: calendar)

        let data = try JSONEncoder().encode(snapshot)
        let restored = try JSONDecoder().decode(WidgetSnapshot.self, from: data)

        #expect(restored == snapshot)
    }
}
