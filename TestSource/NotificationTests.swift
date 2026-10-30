import Foundation
import Testing
@testable import IosCW

@MainActor
struct NotificationRulesTests {
    private let calendar = TestClock.calendar

    private func usage(_ id: String, spent: Double, limit: Double = 1000) -> BudgetUsage {
        BudgetUsage(categoryID: id, name: "Cat \(id)", spent: spent, limit: limit)
    }

    private func forecast(day: Int, income: Double, expenses: Double) -> ForecastResult {
        func figure(_ value: Double) -> ForecastFigure {
            ForecastFigure(soFar: value / 2, expected: value, low: value / 2, high: value * 2)
        }
        return ForecastResult(month: TestClock.date(2026, 10, 1, hour: 0),
                              dayOfMonth: day,
                              daysInMonth: 31,
                              income: figure(income),
                              expenses: figure(expenses),
                              categories: [],
                              history: [])
    }

    @Test("A budget at 70% is quiet, at 80% almost used, at 100% or more over budget")
    func budgetLevels() {
        let alerts = NotificationRules.budgetAlerts(
            [usage("a", spent: 700), usage("b", spent: 800), usage("c", spent: 1000), usage("d", spent: 2000)],
            monthKey: "2026-10",
            alreadySent: [])

        #expect(Set(alerts.map(\.key)) == ["budget.b.2026-10.near", "budget.c.2026-10.over", "budget.d.2026-10.over"])
    }

    @Test("Past the limit only the over budget alert is made, never both")
    func overReplacesNear() {
        let alerts = NotificationRules.budgetAlerts([usage("a", spent: 1200)], monthKey: "2026-10", alreadySent: [])

        #expect(alerts.map(\.key) == ["budget.a.2026-10.over"])
        #expect(alerts.first?.notification.title == "Over budget")
        #expect(alerts.first?.notification.body == "You have passed your Cat a budget this month.")
    }

    @Test("The almost used message shows the percentage but no money amount")
    func nearMessage() {
        let alerts = NotificationRules.budgetAlerts([usage("a", spent: 850)], monthKey: "2026-10", alreadySent: [])

        #expect(alerts.first?.notification.title == "Budget almost used")
        #expect(alerts.first?.notification.body == "Cat a is at 85% of its monthly limit.")
    }

    @Test("An alert already sent this month is not made again")
    func noRepeats() {
        let alerts = NotificationRules.budgetAlerts(
            [usage("a", spent: 850), usage("b", spent: 1500)],
            monthKey: "2026-10",
            alreadySent: ["budget.a.2026-10.near"])

        #expect(alerts.map(\.key) == ["budget.b.2026-10.over"])
    }

    @Test("A budget with no limit never alerts")
    func noLimit() {
        #expect(NotificationRules.budgetAlerts([usage("a", spent: 500, limit: 0)], monthKey: "2026-10", alreadySent: []).isEmpty)
    }

    @Test("The forecast warning needs spending above income, some income, and day 7 or later")
    func forecastWarningConditions() {
        let key = "forecast.2026-10"

        #expect(NotificationRules.forecastAlert(forecast(day: 15, income: 10_000, expenses: 12_000), monthKey: "2026-10", alreadySent: [])?.key == key)
        #expect(NotificationRules.forecastAlert(forecast(day: 6, income: 10_000, expenses: 12_000), monthKey: "2026-10", alreadySent: []) == nil)
        #expect(NotificationRules.forecastAlert(forecast(day: 15, income: 10_000, expenses: 9_000), monthKey: "2026-10", alreadySent: []) == nil)
        #expect(NotificationRules.forecastAlert(forecast(day: 15, income: 0, expenses: 9_000), monthKey: "2026-10", alreadySent: []) == nil)
        #expect(NotificationRules.forecastAlert(forecast(day: 15, income: 10_000, expenses: 12_000), monthKey: "2026-10", alreadySent: [key]) == nil)
    }

    @Test("Alerts are ordered with over budget first, then by name")
    func ordering() {
        let alerts = NotificationRules.budgetAlerts(
            [usage("b", spent: 850), usage("a", spent: 900), usage("c", spent: 1500)],
            monthKey: "2026-10",
            alreadySent: [])

        #expect(NotificationRules.ordered(alerts).map(\.key) == [
            "budget.c.2026-10.over",
            "budget.a.2026-10.near",
            "budget.b.2026-10.near"
        ])
    }

    @Test("Month keys and the current-month check")
    func monthKeys() {
        #expect(NotificationRules.monthKey(TestClock.date(2026, 10, 20), calendar: calendar) == "2026-10")
        #expect(NotificationRules.isCurrent("budget.x.2026-10.near", monthKey: "2026-10"))
        #expect(NotificationRules.isCurrent("forecast.2026-10", monthKey: "2026-10"))
        #expect(!NotificationRules.isCurrent("budget.x.2026-9.near", monthKey: "2026-10"))
        #expect(!NotificationRules.isCurrent("forecast.2026-10", monthKey: "2026-1"))
        #expect(NotificationRules.isCurrent("forecast.2026-1", monthKey: "2026-1"))
    }

    @Test("The new month reminder repeats on the 1st at 9:00")
    func monthlyPlan() {
        let plan = NotificationRules.monthlyPlan

        #expect(plan.id == NotificationRules.monthlyPlanID)
        #expect(plan.trigger == .at(DateComponents(day: 1, hour: 9, minute: 0), repeats: true))
    }

    @Test("The reminder is 3 days after the last activity at 6 pm")
    func reminderThreeDaysLater() {
        let date = NotificationRules.reminderDate(lastActivity: TestClock.date(2026, 10, 18, hour: 10),
                                                  now: TestClock.date(2026, 10, 20),
                                                  calendar: calendar)
        #expect(date == TestClock.date(2026, 10, 21, hour: 18))
    }

    @Test("If the 3 days are already over, the reminder is the next 6 pm")
    func reminderAlreadyDue() {
        let beforeSixPm = NotificationRules.reminderDate(lastActivity: TestClock.date(2026, 10, 10),
                                                         now: TestClock.date(2026, 10, 20),
                                                         calendar: calendar)
        let afterSixPm = NotificationRules.reminderDate(lastActivity: TestClock.date(2026, 10, 10),
                                                        now: TestClock.date(2026, 10, 20, hour: 20),
                                                        calendar: calendar)

        #expect(beforeSixPm == TestClock.date(2026, 10, 20, hour: 18))
        #expect(afterSixPm == TestClock.date(2026, 10, 21, hour: 18))
    }

    @Test("No activity yet means no reminder")
    func reminderNeedsActivity() {
        #expect(NotificationRules.reminderDate(lastActivity: nil, now: TestClock.date(2026, 10, 20), calendar: calendar) == nil)
    }

    @Test("The reminder notification carries the exact date and does not repeat")
    func reminderTrigger() {
        let notification = NotificationRules.reminder(at: TestClock.date(2026, 10, 21, hour: 18), calendar: calendar)

        guard case .at(let parts, let repeats) = notification.trigger else {
            Issue.record("expected a calendar trigger")
            return
        }
        #expect(!repeats)
        #expect(parts.year == 2026)
        #expect(parts.month == 10)
        #expect(parts.day == 21)
        #expect(parts.hour == 18)
        #expect(parts.minute == 0)
        #expect(notification.id == NotificationRules.reminderID)
    }

    @Test("Notification text never contains a money amount")
    func noAmountsInText() {
        let texts = NotificationRules.budgetAlerts([usage("a", spent: 850), usage("b", spent: 1500)],
                                                   monthKey: "2026-10",
                                                   alreadySent: [])
            .map { $0.notification.body }
            + [NotificationRules.monthlyPlan.body, NotificationRules.test.body,
               NotificationRules.reminder(at: Date(), calendar: calendar).body]

        for text in texts {
            #expect(!text.contains("LKR"))
            #expect(!text.contains("Rs"))
        }
    }
}

@MainActor
struct NotificationSettingsStoreTests {
    @Test("Settings are saved and loaded, and default to off")
    func settingsRoundTrip() {
        let store = NotificationSettingsStore(defaults: isolatedDefaults())
        #expect(store.load() == NotificationSettings())
        #expect(!store.load().isOn)

        let changed = NotificationSettings(isOn: true, budgetAlerts: false, forecastWarning: true, monthlyPlan: false, reminder: true)
        store.save(changed)

        #expect(store.load() == changed)
    }

    @Test("Sent alert keys are saved and can be cleared")
    func sentKeys() {
        let store = NotificationSettingsStore(defaults: isolatedDefaults())
        store.saveSentKeys(["a", "b"])
        #expect(store.sentKeys() == ["a", "b"])

        store.clearSentKeys()

        #expect(store.sentKeys().isEmpty)
    }
}

@MainActor
struct NotificationFixture {
    let scheduler = FakeScheduler()
    let store: NotificationSettingsStore
    let categories: CoreDataCategoryRepository
    let expenses: CoreDataExpenseRepository
    let budgets: CoreDataBudgetRepository
    let manager: NotificationManager

    init(enabled: Bool = true,
         settings: NotificationSettings? = nil,
         now: Date? = nil) throws {
        let clockNow = now ?? TestClock.date(2026, 10, 20)
        let persistence = PersistenceController(inMemory: true)
        let categories = CoreDataCategoryRepository(persistence: persistence)
        try categories.seedDefaultsIfNeeded()
        let store = NotificationSettingsStore(defaults: isolatedDefaults())
        if let settings {
            store.save(settings)
        } else if enabled {
            store.save(NotificationSettings(isOn: true))
        }
        let expenses = CoreDataExpenseRepository(persistence: persistence)
        let budgets = CoreDataBudgetRepository(persistence: persistence)
        let scheduler = self.scheduler

        self.store = store
        self.categories = categories
        self.expenses = expenses
        self.budgets = budgets
        self.manager = NotificationManager(expenses: expenses,
                                           budgets: budgets,
                                           scheduler: scheduler,
                                           store: store,
                                           calendar: TestClock.calendar,
                                           now: { clockNow })
    }

    func category(_ name: String) throws -> ExpenseCategory {
        guard let found = categories.fetchAll().first(where: { $0.name == name }) else { throw TestError() }
        return found
    }

    func giveFoodBudget(limit: Double = 10_000, spent: Double, on date: Date? = nil) throws {
        let food = try category("Food & Dining")
        try budgets.setLimit(limit, for: food)
        try expenses.add(ExpenseDraft(amount: spent, date: date ?? TestClock.date(2026, 10, 5), category: food))
    }
}

@MainActor
struct NotificationManagerTests {
    @Test("With notifications off nothing is scheduled and everything pending is cancelled")
    func offDoesNothing() async throws {
        let fixture = try NotificationFixture(enabled: false)
        try fixture.giveFoodBudget(spent: 9_500)

        await fixture.manager.refresh()

        #expect(fixture.scheduler.scheduled.isEmpty)
        #expect(fixture.scheduler.cancelAllCount == 1)
    }

    @Test("Without iOS permission nothing is scheduled")
    func deniedPermission() async throws {
        let fixture = try NotificationFixture()
        fixture.scheduler.permissionValue = .denied
        try fixture.giveFoodBudget(spent: 9_500)

        await fixture.manager.refresh()

        #expect(fixture.scheduler.scheduled.isEmpty)
    }

    @Test("A budget at 85% makes an almost used alert, once")
    func nearAlertOnce() async throws {
        let fixture = try NotificationFixture()
        try fixture.giveFoodBudget(spent: 8_500)

        await fixture.manager.refresh()
        await fixture.manager.refresh()

        let alerts = fixture.scheduler.scheduled(titled: "Budget almost used")
        #expect(alerts.count == 1)
        #expect(alerts.first?.body == "Food & Dining is at 85% of its monthly limit.")
    }

    @Test("Going over the limit makes a second, over budget alert, once")
    func escalation() async throws {
        let fixture = try NotificationFixture()
        try fixture.giveFoodBudget(spent: 8_500)
        await fixture.manager.refresh()

        let food = try fixture.category("Food & Dining")
        try fixture.expenses.add(ExpenseDraft(amount: 2_000, date: TestClock.date(2026, 10, 6), category: food))
        await fixture.manager.refresh()
        await fixture.manager.refresh()

        #expect(fixture.scheduler.scheduled(titled: "Budget almost used").count == 1)
        #expect(fixture.scheduler.scheduled(titled: "Over budget").count == 1)
    }

    @Test("Spending from last month does not count")
    func otherMonth() async throws {
        let fixture = try NotificationFixture()
        try fixture.giveFoodBudget(spent: 9_500, on: TestClock.date(2026, 9, 25))

        await fixture.manager.refresh()

        #expect(fixture.scheduler.scheduled(titled: "Budget almost used").isEmpty)
        #expect(fixture.scheduler.scheduled(titled: "Over budget").isEmpty)
    }

    @Test("The budget alerts switch turns them off")
    func budgetAlertsOff() async throws {
        let fixture = try NotificationFixture(settings: NotificationSettings(isOn: true, budgetAlerts: false))
        try fixture.giveFoodBudget(spent: 9_500)

        await fixture.manager.refresh()

        #expect(fixture.scheduler.scheduled(titled: "Budget almost used").isEmpty)
    }

    @Test("At most 3 alerts are shown at once, and the rest are not repeated later")
    func cappedAtThree() async throws {
        let fixture = try NotificationFixture()
        for name in ["Food & Dining", "Groceries", "Transport", "Shopping", "Health"] {
            let category = try fixture.category(name)
            try fixture.budgets.setLimit(1_000, for: category)
            try fixture.expenses.add(ExpenseDraft(amount: 1_500, date: TestClock.date(2026, 10, 5), category: category))
        }

        await fixture.manager.refresh()
        await fixture.manager.refresh()

        #expect(fixture.scheduler.scheduled(titled: "Over budget").count == 3)
        #expect(fixture.store.sentKeys().count == 5)
    }

    @Test("Spending ahead of income makes a forecast warning")
    func forecastWarning() async throws {
        let fixture = try NotificationFixture()
        for month in [7, 8, 9, 10] {
            try fixture.expenses.add(ExpenseDraft(type: .income, amount: 10_000, date: TestClock.date(2026, month, 1)))
        }
        for month in [7, 8, 9] {
            try fixture.expenses.add(ExpenseDraft(amount: 3_000, date: TestClock.date(2026, month, 10)))
        }
        try fixture.expenses.add(ExpenseDraft(amount: 15_000, date: TestClock.date(2026, 10, 5)))

        await fixture.manager.refresh()
        await fixture.manager.refresh()

        #expect(fixture.scheduler.scheduled(titled: "Spending is running ahead of income").count == 1)
    }

    @Test("The new month reminder is scheduled once and removed when switched off")
    func monthlyPlanSwitch() async throws {
        let fixture = try NotificationFixture()

        await fixture.manager.refresh()
        await fixture.manager.refresh()
        #expect(fixture.scheduler.scheduled.filter { $0.id == NotificationRules.monthlyPlanID }.count == 1)

        await fixture.manager.save(NotificationSettings(isOn: true, monthlyPlan: false))

        #expect(fixture.scheduler.cancelledIDs.contains(NotificationRules.monthlyPlanID))
        #expect(fixture.scheduler.pending[NotificationRules.monthlyPlanID] == nil)
    }

    @Test("The forgot reminder is scheduled when on and removed when switched off")
    func reminderSwitch() async throws {
        let fixture = try NotificationFixture(settings: NotificationSettings(isOn: true, reminder: true))
        try fixture.giveFoodBudget(spent: 100)

        await fixture.manager.refresh()
        #expect(fixture.scheduler.pending[NotificationRules.reminderID] != nil)

        await fixture.manager.save(NotificationSettings(isOn: true, reminder: false))

        #expect(fixture.scheduler.pending[NotificationRules.reminderID] == nil)
    }

    @Test("No reminder is scheduled before anything has been added")
    func reminderNeedsData() async throws {
        let fixture = try NotificationFixture(settings: NotificationSettings(isOn: true, reminder: true))

        await fixture.manager.refresh()

        #expect(fixture.scheduler.pending[NotificationRules.reminderID] == nil)
    }

    @Test("Turning on asks iOS for permission and switches the setting on")
    func turnOnAllowed() async throws {
        let fixture = try NotificationFixture(enabled: false)
        fixture.scheduler.permissionValue = .notDetermined

        let result = await fixture.manager.turnOn()

        #expect(result == .allowed)
        #expect(fixture.scheduler.requestCount == 1)
        #expect(fixture.manager.settings().isOn)
    }

    @Test("If the user says no, the setting stays off")
    func turnOnDenied() async throws {
        let fixture = try NotificationFixture(enabled: false)
        fixture.scheduler.permissionValue = .notDetermined
        fixture.scheduler.requestResult = false

        let result = await fixture.manager.turnOn()

        #expect(result == .denied)
        #expect(!fixture.manager.settings().isOn)
    }

    @Test("Permission that was already given is not asked for again")
    func permissionNotAskedTwice() async throws {
        let fixture = try NotificationFixture(enabled: false)

        let result = await fixture.manager.turnOn()

        #expect(result == .allowed)
        #expect(fixture.scheduler.requestCount == 0)
    }

    @Test("Reset cancels everything and lets alerts be made again for the next user")
    func resetOnSignOut() async throws {
        let fixture = try NotificationFixture()
        try fixture.giveFoodBudget(spent: 8_500)
        await fixture.manager.refresh()
        #expect(fixture.scheduler.scheduled(titled: "Budget almost used").count == 1)

        await fixture.manager.reset()

        #expect(fixture.scheduler.cancelAllCount == 1)
        #expect(fixture.store.sentKeys().isEmpty)
        await fixture.manager.refresh()
        #expect(fixture.scheduler.scheduled(titled: "Budget almost used").count == 2)
    }

    @Test("The test notification is only sent when allowed")
    func testNotification() async throws {
        let allowed = try NotificationFixture()
        await allowed.manager.sendTest()
        #expect(allowed.scheduler.scheduled.map(\.id) == [NotificationRules.testID])

        let denied = try NotificationFixture()
        denied.scheduler.permissionValue = .denied
        await denied.manager.sendTest()
        #expect(denied.scheduler.scheduled.isEmpty)
    }
}

@MainActor
struct NotificationSettingsViewModelTests {
    @Test("Switching on with permission shows no message")
    func switchOn() async throws {
        let fixture = try NotificationFixture(enabled: false)
        let viewModel = NotificationSettingsViewModel(manager: fixture.manager)
        #expect(!viewModel.settings.isOn)

        await viewModel.setOn(true)

        #expect(viewModel.settings.isOn)
        #expect(viewModel.message == nil)
        #expect(viewModel.permission == .allowed)
    }

    @Test("Switching on without permission explains how to fix it and stays off")
    func switchOnDenied() async throws {
        let fixture = try NotificationFixture(enabled: false)
        fixture.scheduler.permissionValue = .notDetermined
        fixture.scheduler.requestResult = false
        let viewModel = NotificationSettingsViewModel(manager: fixture.manager)

        await viewModel.setOn(true)

        #expect(!viewModel.settings.isOn)
        #expect(viewModel.message != nil)
        #expect(viewModel.isDenied)
    }

    @Test("Changing a switch is saved")
    func updateSaves() async throws {
        let fixture = try NotificationFixture()
        let viewModel = NotificationSettingsViewModel(manager: fixture.manager)
        var changed = viewModel.settings
        changed.reminder = true

        await viewModel.update(changed)

        #expect(viewModel.settings.reminder)
        #expect(fixture.manager.settings().reminder)
    }

    @Test("Switching off cancels pending notifications")
    func switchOff() async throws {
        let fixture = try NotificationFixture()
        let viewModel = NotificationSettingsViewModel(manager: fixture.manager)

        await viewModel.setOn(false)

        #expect(!fixture.manager.settings().isOn)
        #expect(fixture.scheduler.cancelAllCount >= 1)
    }
}
