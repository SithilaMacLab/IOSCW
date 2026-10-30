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
    let accountDeletion: AccountDeleting
    let predictor: NextMonthModelProviding

    init(persistence: PersistenceController,
         auth: AuthServiceProtocol,
         rates: ExchangeRateServiceProtocol = CachedExchangeRateService(),
         remote: RemoteStoreProtocol? = nil,
         network: NetworkMonitor = NetworkMonitor(),
         recognizer: TextRecognizing = VisionTextRecognizer(),
         location: LocationProviding = DeviceLocationProvider(),
         publishesWidget: Bool = false,
         modelDefaults: UserDefaults = .standard) {
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
        accountDeletion = AccountDeletionService(auth: auth,
                                                 remote: remote,
                                                 sync: sync,
                                                 persistence: persistence,
                                                 categories: categories,
                                                 widget: widget,
                                                 network: network)
        predictor = NextMonthModelService(expenses: expenses,
                                          store: NextMonthModelStore(defaults: modelDefaults))
    }

    static let isUITesting = ProcessInfo.processInfo.arguments.contains("-uitest")

    static let live: AppContainer = isUITesting
        ? uiTestContainer()
        : AppContainer(persistence: .shared,
                       auth: AuthServiceFactory.makeLive(),
                       remote: RemoteStoreFactory.makeLive(),
                       publishesWidget: true)

    private static func uiTestContainer() -> AppContainer {
        let suite = "pocketlens.uitest"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        UserDefaults.standard.removeObject(forKey: AppLockViewModel.enabledKey)
        if ProcessInfo.processInfo.arguments.contains("-uitest-signedin") {
            defaults.set("ui.tester@example.com", forKey: DevAuthService.storageKey)
        }
        return AppContainer(persistence: PersistenceController(inMemory: true),
                            auth: DevAuthService(defaults: defaults),
                            rates: StaticExchangeRateService(),
                            location: StaticLocationProvider(),
                            modelDefaults: defaults)
    }

    static func preview(withSamples: Bool = true) -> AppContainer {
        let container = AppContainer(persistence: PersistenceController(inMemory: true),
                                     auth: DevAuthService(defaults: UserDefaults(suiteName: "preview") ?? .standard),
                                     rates: StaticExchangeRateService(),
                                     location: StaticLocationProvider(),
                                     modelDefaults: UserDefaults(suiteName: "preview-model") ?? .standard)
        if withSamples { SampleData.populate(container) }
        return container
    }
}
