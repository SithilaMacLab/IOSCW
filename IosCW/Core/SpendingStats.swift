import Foundation

struct CategoryTotal: Identifiable, Equatable {
    let id: String
    let name: String
    let colorHex: String
    let iconName: String
    let total: Double
}

struct MonthTotal: Identifiable, Equatable {
    var id: Date { month }
    let month: Date
    let income: Double
    let expenses: Double
}

enum SpendingStats {
    static func total(of type: TransactionType,
                      in expenses: [Expense],
                      month: Date = Date(),
                      calendar: Calendar = .current) -> Double {
        expenses
            .filter { $0.type == type && calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
            .reduce(0) { $0 + $1.amountLKR }
    }

    static func expensesByCategory(_ expenses: [Expense],
                                   month: Date = Date(),
                                   calendar: Calendar = .current) -> [CategoryTotal] {
        let monthExpenses = expenses.filter {
            $0.type == .expense && calendar.isDate($0.date, equalTo: month, toGranularity: .month)
        }
        let groups = Dictionary(grouping: monthExpenses) { $0.category?.id.uuidString ?? "none" }

        return groups.map { key, items in
            let category = items.first?.category
            return CategoryTotal(
                id: key,
                name: category?.name ?? "Uncategorised",
                colorHex: category?.colorHex ?? "#8E8E93",
                iconName: category?.iconName ?? "questionmark.circle.fill",
                total: items.reduce(0) { $0 + $1.amountLKR }
            )
        }
        .sorted { $0.total > $1.total }
    }

    static func monthlyTrend(_ expenses: [Expense],
                             months: Int = 6,
                             now: Date = Date(),
                             calendar: Calendar = .current) -> [MonthTotal] {
        guard let thisMonth = calendar.dateInterval(of: .month, for: now)?.start else { return [] }

        return (0..<months).reversed().compactMap { offset in
            guard let month = calendar.date(byAdding: .month, value: -offset, to: thisMonth) else { return nil }
            return MonthTotal(
                month: month,
                income: total(of: .income, in: expenses, month: month, calendar: calendar),
                expenses: total(of: .expense, in: expenses, month: month, calendar: calendar)
            )
        }
    }
}
