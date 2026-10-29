import Foundation

final class AppContainer {
    let persistence: PersistenceController
    let auth: AuthServiceProtocol
    let rates: ExchangeRateServiceProtocol
    let network: NetworkMonitor
    let recognizer: TextRecognizing
    let location: LocationProviding
    let categories: CategoryRepositoryProtocol
    let expenses: ExpenseRepositoryProtocol
    let budgets: BudgetRepositoryProtocol
    let sync: SyncEngine
    let widget: WidgetPublishing

    init(persistence: PersistenceController,
         auth: AuthServiceProtocol,
         rates: ExchangeRateServiceProtocol = CachedExchangeRateService(),
         remote: RemoteStoreProtocol? = nil,
         network: NetworkMonitor = NetworkMonitor(),
         recognizer: TextRecognizing = VisionTextRecognizer(),
         location: LocationProviding = DeviceLocationProvider(),
         publishesWidget: Bool = false) {
        self.persistence = persistence
        self.auth = auth
        self.rates = rates
        self.network = network
        self.recognizer = recognizer
        self.location = location
        categories = CoreDataCategoryRepository(persistence: persistence)
        expenses = CoreDataExpenseRepository(persistence: persistence)
        budgets = CoreDataBudgetRepository(persistence: persistence)
        try? categories.seedDefaultsIfNeeded()
        sync = SyncEngine(persistence: persistence,
                          remote: remote,
                          auth: auth,
                          network: network,
                          categories: categories)
        widget = publishesWidget
            ? WidgetPublisher(expenses: expenses, budgets: budgets, auth: auth)
            : NoWidgetPublisher()
    }

    static let live = AppContainer(persistence: .shared,
                                   auth: AuthServiceFactory.makeLive(),
                                   remote: RemoteStoreFactory.makeLive(),
                                   publishesWidget: true)

    static func preview(withSamples: Bool = true) -> AppContainer {
        let container = AppContainer(persistence: PersistenceController(inMemory: true),
                                     auth: DevAuthService(defaults: UserDefaults(suiteName: "preview") ?? .standard),
                                     rates: StaticExchangeRateService(),
                                     location: StaticLocationProvider())
        if withSamples { SampleData.populate(container) }
        return container
    }
}
