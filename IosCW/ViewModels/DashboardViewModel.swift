import Combine
import Foundation

struct TrendPoint: Identifiable {
    let month: Date
    let kind: String
    let amount: Double

    var id: String { "\(month.timeIntervalSince1970)-\(kind)" }
}

final class DashboardViewModel: ObservableObject {
    @Published private(set) var monthIncome: Double = 0
    @Published private(set) var monthExpenses: Double = 0
    @Published private(set) var categoryTotals: [CategoryTotal] = []
    @Published private(set) var trend: [TrendPoint] = []
    @Published private(set) var hasAnyTransactions = false

    private let repository: ExpenseRepositoryProtocol
    private var observer: AnyCancellable?

    init(expenses: ExpenseRepositoryProtocol) {
        repository = expenses
        reload()
        observer = observeDataChanges { [weak self] in self?.reload() }
    }

    var balance: Double { monthIncome - monthExpenses }

    func reload() {
        let transactions = repository.fetchAll()
        hasAnyTransactions = !transactions.isEmpty
        monthIncome = SpendingStats.total(of: .income, in: transactions)
        monthExpenses = SpendingStats.total(of: .expense, in: transactions)
        categoryTotals = SpendingStats.expensesByCategory(transactions)
        trend = SpendingStats.monthlyTrend(transactions).flatMap { month in
            [TrendPoint(month: month.month, kind: "Income", amount: month.income),
             TrendPoint(month: month.month, kind: "Expenses", amount: month.expenses)]
        }
    }
}
