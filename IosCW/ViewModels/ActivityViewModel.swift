import Combine
import Foundation

final class ActivityViewModel: ObservableObject {
    @Published private(set) var allTransactions: [Expense] = []
    @Published private(set) var categories: [ExpenseCategory] = []
    @Published var filter = ExpenseFilter()
    @Published var sort: ExpenseSort = .newest
    @Published var errorMessage: String?

    private let expenseRepository: ExpenseRepositoryProtocol
    private let categoryRepository: CategoryRepositoryProtocol
    private var observer: AnyCancellable?

    init(expenses: ExpenseRepositoryProtocol, categories: CategoryRepositoryProtocol) {
        expenseRepository = expenses
        categoryRepository = categories
        reload()
        observer = observeDataChanges { [weak self] in self?.reload() }
    }

    var visibleTransactions: [Expense] {
        sort.sorted(allTransactions.filter { filter.matches($0) })
    }

    func reload() {
        allTransactions = expenseRepository.fetchAll()
        categories = categoryRepository.fetchAll()
    }

    func delete(_ expense: Expense) {
        do {
            try expenseRepository.delete(expense)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
