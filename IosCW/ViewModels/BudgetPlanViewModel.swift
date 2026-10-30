import Combine
import Foundation

final class BudgetPlanViewModel: ObservableObject {
    static let rateKey = "budgetPlanSavingsRate"
    static let defaultRate = 0.2

    @Published var savingsRate: Double {
        didSet {
            defaults.set(savingsRate, forKey: Self.rateKey)
            plan = BudgetPlanner.plan(for: forecast, savingsRate: savingsRate)
            appliedCount = nil
        }
    }

    @Published private(set) var plan: BudgetPlan
    @Published private(set) var currentLimits: [String: Double] = [:]
    @Published private(set) var appliedCount: Int?
    @Published var errorMessage: String?

    private let forecast: NextMonthForecast
    private let budgets: BudgetRepositoryProtocol
    private let categories: CategoryRepositoryProtocol
    private let defaults: UserDefaults

    init(forecast: NextMonthForecast,
         budgets: BudgetRepositoryProtocol,
         categories: CategoryRepositoryProtocol,
         defaults: UserDefaults = .standard) {
        self.forecast = forecast
        self.budgets = budgets
        self.categories = categories
        self.defaults = defaults

        let saved = defaults.object(forKey: Self.rateKey) as? Double ?? Self.defaultRate
        let rate = min(max(saved, 0), BudgetPlanner.maximumSavingsRate)
        savingsRate = rate
        plan = BudgetPlanner.plan(for: forecast, savingsRate: rate)
        loadCurrentLimits()
    }

    var changedLineCount: Int {
        plan.lines.filter { abs((currentLimits[$0.id] ?? 0) - $0.limit) >= 1 }.count
    }

    func apply() {
        errorMessage = nil
        let byID = Dictionary(categories.fetchAll().map { ($0.id.uuidString, $0) },
                              uniquingKeysWith: { first, _ in first })
        var count = 0

        for line in plan.lines {
            guard let category = byID[line.id] else { continue }
            do {
                try budgets.setLimit(line.limit, for: category)
                count += 1
            } catch {
                errorMessage = error.localizedDescription
                loadCurrentLimits()
                return
            }
        }

        appliedCount = count
        loadCurrentLimits()
    }

    private func loadCurrentLimits() {
        var limits = [String: Double]()
        for budget in budgets.fetchAll() {
            if let id = budget.category?.id.uuidString {
                limits[id] = budget.monthlyLimit
            }
        }
        currentLimits = limits
    }
}
