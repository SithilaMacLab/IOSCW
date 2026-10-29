import Foundation
import Testing
@testable import IosCW

@MainActor
struct BudgetTests {
    @Test("Status changes at 80% and 100% of the limit", arguments: [
        (0.0, BudgetStatus.onTrack),
        (0.79, BudgetStatus.onTrack),
        (0.8, BudgetStatus.nearLimit),
        (0.99, BudgetStatus.nearLimit),
        (1.0, BudgetStatus.overBudget),
        (2.5, BudgetStatus.overBudget)
    ])
    func statusThresholds(progress: Double, expected: BudgetStatus) {
        #expect(BudgetStatus(progress: progress) == expected)
    }

    @Test("Every status has a title and an icon, so colour is never the only signal")
    func statusHasTextAndIcon() {
        for status in [BudgetStatus.onTrack, .nearLimit, .overBudget] {
            #expect(!status.title.isEmpty)
            #expect(!status.systemImage.isEmpty)
        }
    }

    @Test("Progress is spent divided by the limit, and zero without a limit")
    func progress() {
        #expect(BudgetMath.progress(spent: 50, limit: 200) == 0.25)
        #expect(BudgetMath.progress(spent: 300, limit: 200) == 1.5)
        #expect(BudgetMath.progress(spent: 50, limit: 0) == 0)
    }

    @Test("Only this month's expenses in the budget's category count")
    func spentCountsTheRightTransactions() throws {
        let persistence = PersistenceController(inMemory: true)
        let categories = CoreDataCategoryRepository(persistence: persistence)
        let expenses = CoreDataExpenseRepository(persistence: persistence)
        try categories.seedDefaultsIfNeeded()

        let groceries = try #require(categories.fetchAll().first { $0.name == "Groceries" })
        let transport = try #require(categories.fetchAll().first { $0.name == "Transport" })

        try expenses.add(ExpenseDraft(amount: 1000, date: TestClock.date(2026, 10, 3), category: groceries))
        try expenses.add(ExpenseDraft(amount: 500, date: TestClock.date(2026, 10, 20), category: groceries))
        try expenses.add(ExpenseDraft(amount: 700, date: TestClock.date(2026, 9, 28), category: groceries))
        try expenses.add(ExpenseDraft(amount: 300, date: TestClock.date(2026, 10, 5), category: transport))
        try expenses.add(ExpenseDraft(type: .income, amount: 2000, date: TestClock.date(2026, 10, 1), category: groceries))

        let spent = BudgetMath.spent(categoryID: groceries.id,
                                     in: expenses.fetchAll(),
                                     month: TestClock.date(2026, 10, 15),
                                     calendar: TestClock.calendar)

        #expect(spent == 1500)
    }

    @Test("Setting a limit twice updates the same budget")
    func limitsAreUpdatedNotDuplicated() throws {
        let persistence = PersistenceController(inMemory: true)
        let categories = CoreDataCategoryRepository(persistence: persistence)
        let budgets = CoreDataBudgetRepository(persistence: persistence)
        try categories.seedDefaultsIfNeeded()
        let food = try #require(categories.fetchAll().first { $0.name == "Food & Dining" })

        try budgets.setLimit(10_000, for: food)
        try budgets.setLimit(15_000, for: food)

        #expect(budgets.fetchAll().count == 1)
        #expect(budgets.fetchAll().first?.monthlyLimit == 15_000)
    }

    @Test("A limit of zero or less is refused")
    func invalidLimit() throws {
        let persistence = PersistenceController(inMemory: true)
        let categories = CoreDataCategoryRepository(persistence: persistence)
        let budgets = CoreDataBudgetRepository(persistence: persistence)
        try categories.seedDefaultsIfNeeded()
        let food = try #require(categories.fetchAll().first { $0.name == "Food & Dining" })

        #expect(throws: BudgetError.self) {
            try budgets.setLimit(0, for: food)
        }
        #expect(budgets.fetchAll().isEmpty)
    }
}
