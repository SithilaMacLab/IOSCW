import Foundation

enum BudgetStatus {
    case onTrack
    case nearLimit
    case overBudget

    init(progress: Double) {
        switch progress {
        case ..<0.8: self = .onTrack
        case ..<1.0: self = .nearLimit
        default: self = .overBudget
        }
    }

    var title: String {
        switch self {
        case .onTrack: "On track"
        case .nearLimit: "Near limit"
        case .overBudget: "Over budget"
        }
    }

    var systemImage: String {
        switch self {
        case .onTrack: "checkmark.circle.fill"
        case .nearLimit: "exclamationmark.triangle.fill"
        case .overBudget: "exclamationmark.octagon.fill"
        }
    }
}

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
