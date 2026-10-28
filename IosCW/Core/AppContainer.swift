import Foundation

final class AppContainer {
    let persistence: PersistenceController
    let auth: AuthServiceProtocol
    let categories: CategoryRepositoryProtocol
    let expenses: ExpenseRepositoryProtocol
    let budgets: BudgetRepositoryProtocol

    init(persistence: PersistenceController, auth: AuthServiceProtocol) {
        self.persistence = persistence
        self.auth = auth
        categories = CoreDataCategoryRepository(persistence: persistence)
        expenses = CoreDataExpenseRepository(persistence: persistence)
        budgets = CoreDataBudgetRepository(persistence: persistence)
        try? categories.seedDefaultsIfNeeded()
    }

    static let live = AppContainer(persistence: .shared, auth: AuthServiceFactory.makeLive())

    static func preview(withSamples: Bool = true) -> AppContainer {
        let container = AppContainer(persistence: PersistenceController(inMemory: true),
                                     auth: DevAuthService(defaults: UserDefaults(suiteName: "preview") ?? .standard))
        if withSamples { SampleData.populate(container) }
        return container
    }
}
