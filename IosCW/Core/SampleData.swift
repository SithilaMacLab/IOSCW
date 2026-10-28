import Foundation

enum SampleData {
    private static let merchants: [String: [String]] = [
        "Food & Dining": ["Cafe Kumbuk", "Pizza Hut", "Burger Lab"],
        "Groceries": ["Keells", "Cargills Food City", "Arpico"],
        "Transport": ["PickMe", "Uber", "Fuel Station"],
        "Shopping": ["Odel", "Daraz", "Cotton Collection"],
        "Bills & Utilities": ["Dialog", "CEB Electricity", "Water Board"],
        "Entertainment": ["Scope Cinemas", "Netflix"],
        "Health": ["Osusala", "Healthguard"]
    ]

    static func populate(_ container: AppContainer) {
        let categories = container.categories.fetchAll()
        let calendar = Calendar.current
        let now = Date()

        for monthOffset in 0..<4 {
            guard let monthStart = calendar.date(byAdding: .month, value: -monthOffset,
                                                 to: calendar.dateInterval(of: .month, for: now)?.start ?? now)
            else { continue }

            if let salary = categories.first(where: { $0.name == "Salary" }) {
                try? container.expenses.add(ExpenseDraft(
                    type: .income, amount: 150_000, date: monthStart,
                    merchant: "Monthly salary", category: salary))
            }

            for (name, shops) in merchants {
                guard let category = categories.first(where: { $0.name == name }) else { continue }
                for _ in 0..<Int.random(in: 1...3) {
                    let day = Int.random(in: 0..<(monthOffset == 0 ? max(calendar.component(.day, from: now) - 1, 1) : 27))
                    let date = calendar.date(byAdding: .day, value: day, to: monthStart) ?? monthStart
                    try? container.expenses.add(ExpenseDraft(
                        amount: Double(Int.random(in: 8...120) * 100),
                        date: date,
                        merchant: shops.randomElement() ?? "",
                        category: category))
                }
            }
        }

        let budgets: [(String, Double)] = [("Food & Dining", 25_000), ("Groceries", 30_000),
                                           ("Transport", 15_000), ("Shopping", 12_000)]
        for (name, limit) in budgets {
            if let category = categories.first(where: { $0.name == name }) {
                try? container.budgets.setLimit(limit, for: category)
            }
        }
    }
}
