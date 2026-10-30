import Combine
import Foundation
import UserNotifications

protocol NotificationScheduling {
    func permission() async -> NotificationPermission
    func requestPermission() async -> Bool
    func schedule(_ notification: LocalNotification) async
    func cancel(ids: [String]) async
    func cancelAll() async
    func pendingIDs() async -> [String]
}

final class NoNotificationScheduler: NotificationScheduling {
    func permission() async -> NotificationPermission { .denied }
    func requestPermission() async -> Bool { false }
    func schedule(_ notification: LocalNotification) async {}
    func cancel(ids: [String]) async {}
    func cancelAll() async {}
    func pendingIDs() async -> [String] { [] }
}

final class SystemNotificationScheduler: NotificationScheduling {
    private let center = UNUserNotificationCenter.current()

    func permission() async -> NotificationPermission {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        default: return .allowed
        }
    }

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func schedule(_ notification: LocalNotification) async {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default

        let trigger: UNNotificationTrigger
        switch notification.trigger {
        case .soon:
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        case .at(let components, let repeats):
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        }

        let request = UNNotificationRequest(identifier: notification.id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    func cancel(ids: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    func cancelAll() async {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    func pendingIDs() async -> [String] {
        await center.pendingNotificationRequests().map { $0.identifier }
    }
}

final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}

final class NotificationSettingsStore {
    static let settingsKey = "notificationSettings"
    static let sentKey = "notificationSentKeys"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> NotificationSettings {
        guard let data = defaults.data(forKey: Self.settingsKey),
              let settings = try? JSONDecoder().decode(NotificationSettings.self, from: data)
        else { return NotificationSettings() }
        return settings
    }

    func save(_ settings: NotificationSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.settingsKey)
    }

    func sentKeys() -> Set<String> {
        Set(defaults.stringArray(forKey: Self.sentKey) ?? [])
    }

    func saveSentKeys(_ keys: Set<String>) {
        defaults.set(Array(keys).sorted(), forKey: Self.sentKey)
    }

    func clearSentKeys() {
        defaults.removeObject(forKey: Self.sentKey)
    }
}

protocol NotificationManaging {
    func settings() -> NotificationSettings
    func permission() async -> NotificationPermission
    func turnOn() async -> NotificationPermission
    func save(_ settings: NotificationSettings) async
    func sendTest() async
    func refresh() async
    func reset() async
}

final class NotificationManager: NotificationManaging {
    private let expenses: ExpenseRepositoryProtocol
    private let budgets: BudgetRepositoryProtocol
    private let scheduler: NotificationScheduling
    private let store: NotificationSettingsStore
    private let calendar: Calendar
    private let now: () -> Date
    private var observer: AnyCancellable?
    private var isRefreshing = false
    private var refreshAgain = false

    init(expenses: ExpenseRepositoryProtocol,
         budgets: BudgetRepositoryProtocol,
         scheduler: NotificationScheduling,
         store: NotificationSettingsStore = NotificationSettingsStore(),
         calendar: Calendar = .current,
         now: @escaping () -> Date = Date.init,
         observesChanges: Bool = false) {
        self.expenses = expenses
        self.budgets = budgets
        self.scheduler = scheduler
        self.store = store
        self.calendar = calendar
        self.now = now

        if observesChanges {
            observer = NotificationCenter.default
                .publisher(for: .pocketlensDataDidChange)
                .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self else { return }
                    Task { await self.refresh() }
                }
        }
    }

    func settings() -> NotificationSettings {
        store.load()
    }

    func permission() async -> NotificationPermission {
        await scheduler.permission()
    }

    func turnOn() async -> NotificationPermission {
        var permission = await scheduler.permission()
        if permission == .notDetermined {
            permission = await scheduler.requestPermission() ? .allowed : .denied
        }
        if permission == .allowed {
            var settings = store.load()
            settings.isOn = true
            store.save(settings)
            await refresh()
        }
        return permission
    }

    func save(_ settings: NotificationSettings) async {
        store.save(settings)
        await refresh()
    }

    func sendTest() async {
        guard await scheduler.permission() == .allowed else { return }
        await scheduler.schedule(NotificationRules.test)
    }

    func reset() async {
        await scheduler.cancelAll()
        store.clearSentKeys()
    }

    func refresh() async {
        if isRefreshing {
            refreshAgain = true
            return
        }
        isRefreshing = true
        repeat {
            refreshAgain = false
            await performRefresh()
        } while refreshAgain
        isRefreshing = false
    }

    private func performRefresh() async {
        let settings = store.load()
        guard settings.isOn else {
            await scheduler.cancelAll()
            return
        }
        guard await scheduler.permission() == .allowed else { return }

        let current = now()
        let monthKey = NotificationRules.monthKey(current, calendar: calendar)
        var sent = store.sentKeys().filter { NotificationRules.isCurrent($0, monthKey: monthKey) }
        let transactions = expenses.fetchAll()

        var planned = [PlannedAlert]()

        if settings.budgetAlerts {
            let usages = budgets.fetchAll().compactMap { budget -> BudgetUsage? in
                guard let category = budget.category else { return nil }
                return BudgetUsage(
                    categoryID: category.id.uuidString,
                    name: category.name,
                    spent: BudgetMath.spent(categoryID: category.id, in: transactions, month: current, calendar: calendar),
                    limit: budget.monthlyLimit)
            }
            planned += NotificationRules.budgetAlerts(usages, monthKey: monthKey, alreadySent: sent)
        }

        if settings.forecastWarning,
           case .ready(let forecast) = ForecastEngine.forecast(transactions.map { ForecastEntry($0) },
                                                               now: current,
                                                               calendar: calendar),
           let alert = NotificationRules.forecastAlert(forecast, monthKey: monthKey, alreadySent: sent) {
            planned.append(alert)
        }

        let ordered = NotificationRules.ordered(planned)
        for alert in ordered.prefix(NotificationRules.maxImmediateAlerts) {
            await scheduler.schedule(alert.notification)
        }
        for alert in ordered {
            sent.insert(alert.key)
        }
        store.saveSentKeys(sent)

        let pending = Set(await scheduler.pendingIDs())
        if settings.monthlyPlan {
            if !pending.contains(NotificationRules.monthlyPlanID) {
                await scheduler.schedule(NotificationRules.monthlyPlan)
            }
        } else if pending.contains(NotificationRules.monthlyPlanID) {
            await scheduler.cancel(ids: [NotificationRules.monthlyPlanID])
        }

        await scheduler.cancel(ids: [NotificationRules.reminderID])
        if settings.reminder,
           let date = NotificationRules.reminderDate(lastActivity: transactions.map { $0.lastEdited }.max(),
                                                     now: current,
                                                     calendar: calendar) {
            await scheduler.schedule(NotificationRules.reminder(at: date, calendar: calendar))
        }
    }
}
