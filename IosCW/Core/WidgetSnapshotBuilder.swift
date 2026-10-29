import Foundation

struct WidgetBudgetInput: Equatable {
    let categoryID: String
    let name: String
    let colorHex: String
    let limit: Double
}

enum WidgetSnapshotBuilder {
    static let maxBudgetLines = 6

    static func make(entries: [ForecastEntry],
                     budgets: [WidgetBudgetInput],
                     now: Date = Date(),
                     calendar: Calendar = .current,
                     currencyCode: String = AppConstants.baseCurrencyCode) -> WidgetSnapshot {
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let thisMonth = entries.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
        let expenses = thisMonth.filter { $0.type == .expense }

        let lines = budgets
            .map { budget in
                WidgetBudgetLine(
                    id: budget.categoryID,
                    name: budget.name,
                    colorHex: budget.colorHex,
                    spent: expenses.filter { $0.categoryID == budget.categoryID }.reduce(0) { $0 + $1.amount },
                    limit: budget.limit)
            }
            .sorted { $0.progress > $1.progress }

        var expected: Double?
        if case .ready(let forecast) = ForecastEngine.forecast(entries, now: now, calendar: calendar) {
            expected = forecast.expenses.expected
        }

        return WidgetSnapshot(
            month: monthStart,
            currencyCode: currencyCode,
            spent: expenses.reduce(0) { $0 + $1.amount },
            income: thisMonth.filter { $0.type == .income }.reduce(0) { $0 + $1.amount },
            totalLimit: lines.reduce(0) { $0 + $1.limit },
            budgetedSpent: lines.reduce(0) { $0 + $1.spent },
            expectedSpending: expected,
            budgets: Array(lines.prefix(maxBudgetLines)),
            updatedAt: now)
    }
}
