import Combine
import Foundation

struct ForecastBar: Identifiable {
    static let spent = "Spent"
    static let expectedRest = "Expected rest"

    let month: Date
    let series: String
    let amount: Double

    var id: String { "\(month.timeIntervalSince1970)-\(series)" }
}

struct CategoryOutlook: Identifiable {
    let forecast: CategoryForecast
    let limit: Double?

    var id: String { forecast.id }

    var status: BudgetStatus? {
        limit.map { BudgetStatus(progress: BudgetMath.progress(spent: forecast.figure.expected, limit: $0)) }
    }
}

struct ForecastAlert: Identifiable, Equatable {
    let id: String
    let message: String
}

final class ForecastViewModel: ObservableObject {
    @Published private(set) var outcome: ForecastOutcome = ForecastEngine.empty
    @Published private(set) var outlooks: [CategoryOutlook] = []
    @Published private(set) var alerts: [ForecastAlert] = []
    @Published private(set) var bars: [ForecastBar] = []

    private let expenseRepository: ExpenseRepositoryProtocol
    private let budgetRepository: BudgetRepositoryProtocol
    private var observer: AnyCancellable?

    init(expenses: ExpenseRepositoryProtocol, budgets: BudgetRepositoryProtocol) {
        expenseRepository = expenses
        budgetRepository = budgets
        reload()
        observer = observeDataChanges { [weak self] in self?.reload() }
    }

    func reload() {
        let result = ForecastEngine.forecast(expenseRepository.fetchAll().map { ForecastEntry($0) })
        outcome = result

        guard case .ready(let forecast) = result else {
            outlooks = []
            alerts = []
            bars = []
            return
        }

        let limits = Dictionary(
            budgetRepository.fetchAll().compactMap { budget -> (String, Double)? in
                guard let category = budget.category else { return nil }
                return (category.id.uuidString, budget.monthlyLimit)
            },
            uniquingKeysWith: { first, _ in first })

        outlooks = forecast.categories.map { CategoryOutlook(forecast: $0, limit: limits[$0.id]) }
        alerts = makeAlerts(for: forecast)
        bars = makeBars(for: forecast)
    }

    private func makeAlerts(for forecast: ForecastResult) -> [ForecastAlert] {
        var found = [ForecastAlert]()

        if forecast.income.expected > 0, forecast.leftOver < 0 {
            found.append(ForecastAlert(
                id: "income",
                message: "You are on track to spend \(CurrencyFormatter.lkr(-forecast.leftOver)) more than you earn this month."))
        }

        for outlook in outlooks {
            guard let limit = outlook.limit, outlook.forecast.figure.expected > limit else { continue }
            let over = outlook.forecast.figure.expected - limit
            found.append(ForecastAlert(
                id: outlook.id,
                message: "\(outlook.forecast.name) is on track to pass its \(CurrencyFormatter.lkr(limit)) limit by \(CurrencyFormatter.lkr(over))."))
        }

        return found
    }

    private func makeBars(for forecast: ForecastResult) -> [ForecastBar] {
        var built = forecast.history.map {
            ForecastBar(month: $0.month, series: ForecastBar.spent, amount: $0.expenses)
        }
        built.append(ForecastBar(month: forecast.month, series: ForecastBar.spent, amount: forecast.expenses.soFar))
        built.append(ForecastBar(month: forecast.month, series: ForecastBar.expectedRest,
                                 amount: max(forecast.expenses.remaining, 0)))
        return built
    }
}
