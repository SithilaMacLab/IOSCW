import Foundation

final class AppContainer {
    let persistence: PersistenceController
    let auth: AuthServiceProtocol
    let rates: ExchangeRateServiceProtocol
    let network: NetworkMonitor
    let categories: CategoryRepositoryProtocol
    let expenses: ExpenseRepositoryProtocol
    let budgets: BudgetRepositoryProtocol
    let sync: SyncEngine

    init(persistence: PersistenceController,
         auth: AuthServiceProtocol,
         rates: ExchangeRateServiceProtocol = CachedExchangeRateService(),
         remote: RemoteStoreProtocol? = nil,
         network: NetworkMonitor = NetworkMonitor()) {
        self.persistence = persistence
        self.auth = auth
        self.rates = rates
        self.network = network
        categories = CoreDataCategoryRepository(persistence: persistence)
        expenses = CoreDataExpenseRepository(persistence: persistence)
        budgets = CoreDataBudgetRepository(persistence: persistence)
        try? categories.seedDefaultsIfNeeded()
        sync = SyncEngine(persistence: persistence,
                          remote: remote,
                          auth: auth,
                          network: network,
                          categories: categories)
    }

    static let live = AppContainer(persistence: .shared,
                                   auth: AuthServiceFactory.makeLive(),
                                   remote: RemoteStoreFactory.makeLive())

    static func preview(withSamples: Bool = true) -> AppContainer {
        let container = AppContainer(persistence: PersistenceController(inMemory: true),
                                     auth: DevAuthService(defaults: UserDefaults(suiteName: "preview") ?? .standard),
                                     rates: StaticExchangeRateService())
        if withSamples { SampleData.populate(container) }
        return container
    }
}
