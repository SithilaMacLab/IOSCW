import Foundation

struct LocalNotification: Equatable {
    enum Trigger: Equatable {
        case soon
        case at(DateComponents, repeats: Bool)
    }

    let id: String
    let title: String
    let body: String
    let trigger: Trigger
}

struct NotificationSettings: Codable, Equatable {
    var isOn = false
    var budgetAlerts = true
    var forecastWarning = true
    var monthlyPlan = true
    var reminder = false
}

enum NotificationPermission: Equatable {
    case notDetermined
    case denied
    case allowed
}

struct BudgetUsage: Equatable {
    let categoryID: String
    let name: String
    let spent: Double
    let limit: Double

    var progress: Double { limit > 0 ? spent / limit : 0 }
}

struct PlannedAlert: Equatable {
    let key: String
    let notification: LocalNotification
    let severity: Int
}

enum NotificationRules {
    static let nearThreshold = 0.8
    static let maxImmediateAlerts = 3
    static let forecastMinimumDay = 7
    static let reminderDays = 3
    static let reminderHour = 18
    static let monthlyPlanID = "pocketlens.monthly-plan"
    static let reminderID = "pocketlens.reminder"
    static let testID = "pocketlens.test"

    static func monthKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)"
    }

    static func isCurrent(_ key: String, monthKey: String) -> Bool {
        key.hasSuffix(".\(monthKey)") || key.contains(".\(monthKey).")
    }

    static func budgetAlerts(_ usages: [BudgetUsage],
                             monthKey: String,
                             alreadySent: Set<String>) -> [PlannedAlert] {
        var alerts = [PlannedAlert]()

        for usage in usages where usage.limit > 0 {
            let progress = usage.progress
            if progress >= 1 {
                let key = "budget.\(usage.categoryID).\(monthKey).over"
                guard !alreadySent.contains(key) else { continue }
                alerts.append(PlannedAlert(
                    key: key,
                    notification: LocalNotification(
                        id: key,
                        title: "Over budget",
                        body: "You have passed your \(usage.name) budget this month.",
                        trigger: .soon),
                    severity: 2))
            } else if progress >= nearThreshold {
                let key = "budget.\(usage.categoryID).\(monthKey).near"
                guard !alreadySent.contains(key) else { continue }
                alerts.append(PlannedAlert(
                    key: key,
                    notification: LocalNotification(
                        id: key,
                        title: "Budget almost used",
                        body: "\(usage.name) is at \(Int((progress * 100).rounded()))% of its monthly limit.",
                        trigger: .soon),
                    severity: 1))
            }
        }

        return alerts
    }

    static func forecastAlert(_ forecast: ForecastResult,
                              monthKey: String,
                              alreadySent: Set<String>) -> PlannedAlert? {
        let key = "forecast.\(monthKey)"
        guard !alreadySent.contains(key),
              forecast.dayOfMonth >= forecastMinimumDay,
              forecast.income.expected > 0,
              forecast.expenses.expected > forecast.income.expected
        else { return nil }

        return PlannedAlert(
            key: key,
            notification: LocalNotification(
                id: key,
                title: "Spending is running ahead of income",
                body: "At this pace you may spend more than you earn this month. Open the Forecast tab to see where.",
                trigger: .soon),
            severity: 1)
    }

    static func ordered(_ alerts: [PlannedAlert]) -> [PlannedAlert] {
        alerts.sorted {
            if $0.severity != $1.severity { return $0.severity > $1.severity }
            return $0.key < $1.key
        }
    }

    static var monthlyPlan: LocalNotification {
        LocalNotification(
            id: monthlyPlanID,
            title: "A new month has started",
            body: "Take a minute to plan this month's budget.",
            trigger: .at(DateComponents(day: 1, hour: 9, minute: 0), repeats: true))
    }

    static var test: LocalNotification {
        LocalNotification(
            id: testID,
            title: "Notifications are on",
            body: "This is how Pocketlens alerts will look.",
            trigger: .soon)
    }

    static func reminderDate(lastActivity: Date?, now: Date, calendar: Calendar) -> Date? {
        guard let lastActivity,
              let later = calendar.date(byAdding: .day, value: reminderDays, to: lastActivity),
              let target = calendar.date(bySettingHour: reminderHour, minute: 0, second: 0, of: later)
        else { return nil }

        if target > now { return target }
        return calendar.nextDate(after: now,
                                 matching: DateComponents(hour: reminderHour, minute: 0),
                                 matchingPolicy: .nextTime)
    }

    static func reminder(at date: Date, calendar: Calendar) -> LocalNotification {
        LocalNotification(
            id: reminderID,
            title: "Anything to add?",
            body: "You have not added a transaction for a few days. Scan a receipt to stay on top of your spending.",
            trigger: .at(calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date), repeats: false))
    }
}
