import Foundation

final class AppContainer {
    let persistence: PersistenceController
    let categories: CategoryRepositoryProtocol
    let expenses: ExpenseRepositoryProtocol
    let budgets: BudgetRepositoryProtocol

    init(persistence: PersistenceController) {
        self.persistence = persistence
        categories = CoreDataCategoryRepository(persistence: persistence)
        expenses = CoreDataExpenseRepository(persistence: persistence)
        budgets = CoreDataBudgetRepository(persistence: persistence)
        try? categories.seedDefaultsIfNeeded()
    }

    static let live = AppContainer(persistence: .shared)

    static func preview(withSamples: Bool = true) -> AppContainer {
        let container = AppContainer(persistence: PersistenceController(inMemory: true))
        if withSamples { SampleData.populate(container) }
        return container
    }
}
