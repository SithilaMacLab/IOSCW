import Foundation
import Testing
@testable import IosCW

@MainActor
private func series(_ value: Double) -> SeriesForecast {
    SeriesForecast(value: value, model: .weighted3, error: nil, backtestPoints: 0, low: value, high: value)
}

@MainActor
private func prediction(_ name: String, _ value: Double, id: String? = nil) -> CategoryPrediction {
    CategoryPrediction(id: id ?? name.lowercased(),
                       name: name,
                       colorHex: "#FF9500",
                       iconName: "fork.knife",
                       forecast: series(value),
                       lastMonth: value)
}

@MainActor
private func nextForecast(income: Double, _ categories: [CategoryPrediction]) -> NextMonthForecast {
    NextMonthForecast(month: TestClock.date(2026, 12, 1, hour: 0),
                      monthsOfHistory: 8,
                      phase: .learned,
                      income: series(income),
                      expenses: series(categories.reduce(0) { $0 + $1.forecast.value }),
                      categories: categories)
}

@MainActor
private func standardForecast(income: Double = 100_000) -> NextMonthForecast {
    nextForecast(income: income, [
        prediction("Groceries", 20_000),
        prediction("Bills & Utilities", 10_000),
        prediction("Food & Dining", 25_000),
        prediction("Shopping", 15_000)
    ])
}

@MainActor
struct BudgetPlannerTests {
    private func limit(_ plan: BudgetPlan, _ name: String) -> Double? {
        plan.lines.first { $0.name == name }?.limit
    }

    @Test("Essentials and flexible categories are told apart by name")
    func classification() {
        #expect(BudgetPlanner.isEssential("Groceries"))
        #expect(BudgetPlanner.isEssential("  health "))
        #expect(BudgetPlanner.isEssential("Bills & Utilities"))
        #expect(!BudgetPlanner.isEssential("Food & Dining"))
        #expect(!BudgetPlanner.isEssential("Gym"))
    }

    @Test("A goal that fits keeps the forecast and saves more than asked")
    func goalFits() {
        let plan = BudgetPlanner.plan(for: standardForecast(), savingsRate: 0.2)

        #expect(plan.hasIncome)
        #expect(plan.isFeasible)
        #expect(isClose(plan.goal, 20_000))
        #expect(limit(plan, "Groceries") == 21_000)
        #expect(limit(plan, "Bills & Utilities") == 10_500)
        #expect(limit(plan, "Food & Dining") == 25_000)
        #expect(limit(plan, "Shopping") == 15_000)
        #expect(isClose(plan.plannedSpending, 71_500))
        #expect(isClose(plan.plannedSavings, 28_500))
    }

    @Test("A tighter goal trims only the flexible categories, in proportion")
    func tighterGoalTrimsFlexible() {
        let plan = BudgetPlanner.plan(for: standardForecast(), savingsRate: 0.4)

        #expect(plan.isFeasible)
        #expect(limit(plan, "Groceries") == 21_000)
        #expect(limit(plan, "Bills & Utilities") == 10_500)
        #expect(limit(plan, "Food & Dining") == 17_800)
        #expect(limit(plan, "Shopping") == 10_700)
        #expect(isClose(plan.plannedSavings, 40_000, tolerance: 100))
    }

    @Test("A goal that is too high is capped at 60% of normal flexible spending and reported honestly")
    func impossibleGoal() {
        let plan = BudgetPlanner.plan(for: standardForecast(), savingsRate: 0.5)

        #expect(!plan.isFeasible)
        #expect(limit(plan, "Food & Dining") == 15_000)
        #expect(limit(plan, "Shopping") == 9_000)
        #expect(limit(plan, "Groceries") == 21_000)
        #expect(isClose(plan.plannedSavings, 44_500))
        #expect(isClose(plan.achievedRate, 0.445))
        #expect(isClose(plan.shortfall, 5_500))
    }

    @Test("The savings rate is limited to 50%")
    func rateIsCapped() {
        let plan = BudgetPlanner.plan(for: standardForecast(), savingsRate: 0.9)
        #expect(plan.savingsRate == 0.5)
    }

    @Test("A savings rate of zero trims nothing")
    func zeroRate() {
        let plan = BudgetPlanner.plan(for: standardForecast(), savingsRate: 0)
        #expect(plan.isFeasible)
        #expect(limit(plan, "Food & Dining") == 25_000)
        #expect(plan.goal == 0)
    }

    @Test("Without income there is no goal and limits follow the forecast")
    func noIncome() {
        let plan = BudgetPlanner.plan(for: standardForecast(income: 0), savingsRate: 0.3)

        #expect(!plan.hasIncome)
        #expect(plan.goal == 0)
        #expect(plan.plannedSavings == 0)
        #expect(plan.isFeasible)
        #expect(limit(plan, "Food & Dining") == 25_000)
        #expect(limit(plan, "Groceries") == 21_000)
    }

    @Test("Only essentials and not enough income is reported as not feasible")
    func essentialsExceedIncome() {
        let forecast = nextForecast(income: 30_000, [prediction("Groceries", 20_000)])

        let plan = BudgetPlanner.plan(for: forecast, savingsRate: 0.5)

        #expect(!plan.isFeasible)
        #expect(limit(plan, "Groceries") == 21_000)
        #expect(isClose(plan.plannedSavings, 9_000))
    }

    @Test("Limits are at least one step and zero forecasts are left out")
    func minimumsAndZeros() {
        let forecast = nextForecast(income: 100_000, [
            prediction("Groceries", 30),
            prediction("Gym", 30),
            prediction("Shopping", 0)
        ])

        let plan = BudgetPlanner.plan(for: forecast, savingsRate: 0.1)

        #expect(limit(plan, "Groceries") == 100)
        #expect(limit(plan, "Gym") == 100)
        #expect(limit(plan, "Shopping") == nil)
    }

    @Test("Lines are split into flexible and essential groups")
    func groups() {
        let plan = BudgetPlanner.plan(for: standardForecast(), savingsRate: 0.2)

        #expect(Set(plan.flexibleLines.map(\.name)) == ["Food & Dining", "Shopping"])
        #expect(Set(plan.essentialLines.map(\.name)) == ["Groceries", "Bills & Utilities"])
        #expect(plan.lines.first { $0.name == "Groceries" }?.change == 1_000)
    }

    @Test("Rounding helpers work in steps of 100")
    func rounding() {
        #expect(BudgetPlanner.roundUp(20_000 * 1.05) == 21_000)
        #expect(BudgetPlanner.roundUp(150.5) == 200)
        #expect(BudgetPlanner.roundNearest(17_812.5) == 17_800)
        #expect(BudgetPlanner.roundNearest(10_687.5) == 10_700)
    }
}

@MainActor
struct BudgetPlanViewModelTests {
    @MainActor
    private struct Fixture {
        let categories: CoreDataCategoryRepository
        let budgets: CoreDataBudgetRepository
        let defaults: UserDefaults
        let forecast: NextMonthForecast
        let groceriesID: String
        let foodID: String

        init() throws {
            let persistence = PersistenceController(inMemory: true)
            let categories = CoreDataCategoryRepository(persistence: persistence)
            try categories.seedDefaultsIfNeeded()
            guard let groceries = categories.fetchAll().first(where: { $0.name == "Groceries" }),
                  let food = categories.fetchAll().first(where: { $0.name == "Food & Dining" }) else {
                throw TestError()
            }

            self.categories = categories
            self.budgets = CoreDataBudgetRepository(persistence: persistence)
            self.defaults = isolatedDefaults()
            self.groceriesID = groceries.id.uuidString
            self.foodID = food.id.uuidString
            self.forecast = nextForecast(income: 100_000, [
                prediction("Groceries", 20_000, id: groceries.id.uuidString),
                prediction("Food & Dining", 25_000, id: food.id.uuidString),
                prediction("Uncategorised", 5_000, id: "none")
            ])
        }

        func makeViewModel() -> BudgetPlanViewModel {
            BudgetPlanViewModel(forecast: forecast, budgets: budgets, categories: categories, defaults: defaults)
        }
    }

    @Test("Applying the plan sets a budget for each real category and skips uncategorised spending")
    func apply() throws {
        let fixture = try Fixture()
        let viewModel = fixture.makeViewModel()
        #expect(viewModel.savingsRate == BudgetPlanViewModel.defaultRate)
        #expect(viewModel.changedLineCount == 3)

        viewModel.apply()

        #expect(viewModel.appliedCount == 2)
        #expect(viewModel.errorMessage == nil)
        #expect(fixture.budgets.fetchAll().count == 2)
        #expect(viewModel.currentLimits[fixture.groceriesID] == 21_000)
        #expect(viewModel.currentLimits[fixture.foodID] == 25_000)
        #expect(viewModel.changedLineCount == 1)
    }

    @Test("Applying again replaces the limits instead of adding budgets")
    func applyTwice() throws {
        let fixture = try Fixture()
        let viewModel = fixture.makeViewModel()
        viewModel.apply()

        viewModel.savingsRate = 0.5
        viewModel.apply()

        #expect(fixture.budgets.fetchAll().count == 2)
        #expect((viewModel.currentLimits[fixture.foodID] ?? 0) < 25_000)
    }

    @Test("Changing the goal recomputes the plan and clears the applied message")
    func changingGoal() throws {
        let fixture = try Fixture()
        let viewModel = fixture.makeViewModel()
        viewModel.apply()
        #expect(viewModel.appliedCount != nil)

        viewModel.savingsRate = 0.45

        #expect(viewModel.appliedCount == nil)
        #expect(viewModel.plan.savingsRate == 0.45)
        #expect(isClose(viewModel.plan.goal, 45_000))
    }

    @Test("The chosen goal is remembered")
    func rateIsRemembered() throws {
        let fixture = try Fixture()
        let first = fixture.makeViewModel()

        first.savingsRate = 0.3
        let second = fixture.makeViewModel()

        #expect(isClose(second.savingsRate, 0.3))
    }
}
