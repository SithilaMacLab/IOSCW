import Foundation

enum BudgetMath {
    static func spent(categoryID: UUID,
                      in expenses: [Expense],
                      month: Date = Date(),
                      calendar: Calendar = .current) -> Double {
        expenses
            .filter {
                $0.type == .expense
                    && $0.category?.id == categoryID
                    && calendar.isDate($0.date, equalTo: month, toGranularity: .month)
            }
            .reduce(0) { $0 + $1.amountLKR }
    }

    static func progress(spent: Double, limit: Double) -> Double {
        limit > 0 ? spent / limit : 0
    }
}
