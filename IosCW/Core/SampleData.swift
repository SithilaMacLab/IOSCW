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

    private static let places: [Place] = [
        Place(latitude: 6.8895, longitude: 79.8553, name: "Bambalapitiya, Colombo"),
        Place(latitude: 6.9344, longitude: 79.8428, name: "Fort, Colombo"),
        Place(latitude: 6.8847, longitude: 79.8620, name: "Havelock Town, Colombo"),
        Place(latitude: 6.8649, longitude: 79.8997, name: "Nugegoda"),
        Place(latitude: 6.8518, longitude: 79.8650, name: "Dehiwala"),
        Place(latitude: 6.9114, longitude: 79.8505, name: "Kollupitiya, Colombo"),
        Place(latitude: 6.9094, longitude: 79.8886, name: "Rajagiriya")
    ]

    static func populate(_ container: AppContainer) {
        let categories = container.categories.fetchAll()
        let calendar = Calendar.current
        let now = Date()

        for monthOffset in 0..<9 {
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
                        category: category,
                        place: places.randomElement()))
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
