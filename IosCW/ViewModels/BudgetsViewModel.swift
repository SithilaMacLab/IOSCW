import Combine
import Foundation

struct BudgetItem: Identifiable {
    let budget: Budget
    let category: ExpenseCategory
    let spent: Double

    var id: UUID { budget.id }
    var limit: Double { budget.monthlyLimit }
    var remaining: Double { limit - spent }
    var progress: Double { BudgetMath.progress(spent: spent, limit: limit) }
    var status: BudgetStatus { BudgetStatus(progress: progress) }
}

final class BudgetsViewModel: ObservableObject {
    @Published private(set) var items: [BudgetItem] = []
    @Published private(set) var categoriesWithoutBudget: [ExpenseCategory] = []
    @Published var errorMessage: String?

    private let budgetRepository: BudgetRepositoryProtocol
    private let expenseRepository: ExpenseRepositoryProtocol
    private let categoryRepository: CategoryRepositoryProtocol
    private var observer: AnyCancellable?

    init(budgets: BudgetRepositoryProtocol,
         expenses: ExpenseRepositoryProtocol,
         categories: CategoryRepositoryProtocol) {
        budgetRepository = budgets
        expenseRepository = expenses
        categoryRepository = categories
        reload()
        observer = observeDataChanges { [weak self] in self?.reload() }
    }

    func reload() {
        let transactions = expenseRepository.fetchAll()
        let budgets = budgetRepository.fetchAll()

        items = budgets
            .compactMap { budget -> BudgetItem? in
                guard let category = budget.category else { return nil }
                let spent = BudgetMath.spent(categoryID: category.id, in: transactions)
                return BudgetItem(budget: budget, category: category, spent: spent)
            }
            .sorted { $0.progress > $1.progress }

        let budgeted = Set(items.map(\.category.id))
        categoriesWithoutBudget = categoryRepository.fetchAll().filter { !budgeted.contains($0.id) }
    }

    func setLimit(_ limit: Double?, for category: ExpenseCategory) -> Bool {
        do {
            try budgetRepository.setLimit(limit ?? 0, for: category)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete(_ item: BudgetItem) {
        do {
            try budgetRepository.delete(item.budget)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
