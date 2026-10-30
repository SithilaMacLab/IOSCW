import Foundation

struct PlanLine: Identifiable, Equatable {
    let id: String
    let name: String
    let colorHex: String
    let iconName: String
    let isEssential: Bool
    let forecast: Double
    let limit: Double

    var change: Double { limit - forecast }
}

struct BudgetPlan: Equatable {
    let income: Double
    let savingsRate: Double
    let goal: Double
    let lines: [PlanLine]
    let plannedSpending: Double
    let plannedSavings: Double
    let isFeasible: Bool
    let hasIncome: Bool

    var achievedRate: Double { income > 0 ? plannedSavings / income : 0 }
    var shortfall: Double { max(goal - plannedSavings, 0) }
    var flexibleLines: [PlanLine] { lines.filter { !$0.isEssential } }
    var essentialLines: [PlanLine] { lines.filter { $0.isEssential } }
}

enum BudgetPlanner {
    static let essentialNames: Set<String> = ["groceries", "transport", "bills & utilities", "health", "education"]
    static let essentialBuffer = 1.05
    static let minimumFlexibleShare = 0.6
    static let maximumSavingsRate = 0.5
    static let step = 100.0

    static func isEssential(_ name: String) -> Bool {
        essentialNames.contains(name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    static func plan(for forecast: NextMonthForecast, savingsRate: Double) -> BudgetPlan {
        let rate = min(max(savingsRate, 0), maximumSavingsRate)
        let income = max(forecast.income.value, 0)
        let hasIncome = income >= step
        let goal = hasIncome ? income * rate : 0

        let predictions = forecast.categories.filter { $0.forecast.value > 0 }
        let essentials = predictions.filter { isEssential($0.name) }
        let flexible = predictions.filter { !isEssential($0.name) }

        let essentialsTotal = essentials.reduce(0) { $0 + roundUp($1.forecast.value * essentialBuffer) }
        let flexibleBase = flexible.reduce(0) { $0 + $1.forecast.value }

        var factor = 1.0
        var fits = true
        if hasIncome {
            let room = income - goal - essentialsTotal
            if flexibleBase > 0 {
                let share = room / flexibleBase
                fits = share >= minimumFlexibleShare
                factor = min(max(share, minimumFlexibleShare), 1)
            } else {
                fits = room >= 0
            }
        }

        var lines = [PlanLine]()
        for prediction in flexible {
            lines.append(PlanLine(id: prediction.id,
                                  name: prediction.name,
                                  colorHex: prediction.colorHex,
                                  iconName: prediction.iconName,
                                  isEssential: false,
                                  forecast: prediction.forecast.value,
                                  limit: max(roundNearest(prediction.forecast.value * factor), step)))
        }
        for prediction in essentials {
            lines.append(PlanLine(id: prediction.id,
                                  name: prediction.name,
                                  colorHex: prediction.colorHex,
                                  iconName: prediction.iconName,
                                  isEssential: true,
                                  forecast: prediction.forecast.value,
                                  limit: roundUp(prediction.forecast.value * essentialBuffer)))
        }

        let spending = lines.reduce(0) { $0 + $1.limit }
        return BudgetPlan(income: income,
                          savingsRate: rate,
                          goal: goal,
                          lines: lines,
                          plannedSpending: spending,
                          plannedSavings: hasIncome ? income - spending : 0,
                          isFeasible: fits,
                          hasIncome: hasIncome)
    }

    static func roundUp(_ value: Double) -> Double {
        max(ceil(value / step - 1e-9) * step, step)
    }

    static func roundNearest(_ value: Double) -> Double {
        (value / step).rounded() * step
    }
}
