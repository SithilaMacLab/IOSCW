import Foundation

nonisolated struct WidgetBudgetLine: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var colorHex: String
    var spent: Double
    var limit: Double

    var progress: Double { limit > 0 ? spent / limit : 0 }
}

nonisolated struct WidgetSnapshot: Codable, Equatable {
    var month: Date
    var currencyCode: String
    var spent: Double
    var income: Double
    var totalLimit: Double
    var budgetedSpent: Double
    var expectedSpending: Double?
    var budgets: [WidgetBudgetLine]
    var updatedAt: Date

    var budgetProgress: Double { totalLimit > 0 ? budgetedSpent / totalLimit : 0 }
}

nonisolated enum WidgetStore {
    static let appGroupID = "group.testdrtive.IosCW"
    static let kind = "PocketlensWidget"
    private static let key = "widgetSnapshot"

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroupID)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static func save(_ snapshot: WidgetSnapshot?) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        if let snapshot, let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
