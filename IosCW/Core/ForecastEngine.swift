import Foundation

struct ForecastEntry: Equatable {
    let date: Date
    let amount: Double
    let type: TransactionType
    let categoryID: String
    let categoryName: String
    let colorHex: String
    let iconName: String
}

extension ForecastEntry {
    init(_ expense: Expense) {
        self.init(date: expense.date,
                  amount: expense.amountLKR,
                  type: expense.type,
                  categoryID: expense.category?.id.uuidString ?? "none",
                  categoryName: expense.category?.name ?? "Uncategorised",
                  colorHex: expense.category?.colorHex ?? "#8E8E93",
                  iconName: expense.category?.iconName ?? "questionmark.circle.fill")
    }
}

struct ForecastFigure: Equatable {
    let soFar: Double
    let expected: Double
    let low: Double
    let high: Double

    var remaining: Double { expected - soFar }
    var progress: Double { expected > 0 ? min(soFar / expected, 1) : 0 }
}

struct CategoryForecast: Identifiable, Equatable {
    let id: String
    let name: String
    let colorHex: String
    let iconName: String
    let figure: ForecastFigure
}

struct ForecastResult: Equatable {
    let month: Date
    let dayOfMonth: Int
    let daysInMonth: Int
    let income: ForecastFigure
    let expenses: ForecastFigure
    let categories: [CategoryForecast]
    let history: [MonthTotal]

    var leftOver: Double { income.expected - expenses.expected }
}

enum ForecastOutcome: Equatable {
    case notEnoughData(monthsWithData: Int, monthsNeeded: Int)
    case ready(ForecastResult)
}

enum ForecastEngine {
    static let historyMonths = 3
    private static let weights: [Double] = [1, 2, 3]

    static var empty: ForecastOutcome {
        .notEnoughData(monthsWithData: 0, monthsNeeded: historyMonths)
    }

    static func forecast(_ entries: [ForecastEntry],
                         now: Date = Date(),
                         calendar: Calendar = .current) -> ForecastOutcome {
        guard let currentStart = calendar.dateInterval(of: .month, for: now)?.start,
              let currentEnd = calendar.date(byAdding: .month, value: 1, to: currentStart),
              let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count
        else { return empty }

        let historyStarts = (1...historyMonths).reversed().compactMap {
            calendar.date(byAdding: .month, value: -$0, to: currentStart)
        }
        guard historyStarts.count == historyMonths else { return empty }

        let monthsWithData = historyStarts.filter { start in
            entries.contains { entry in
                entry.type == .expense && calendar.isDate(entry.date, equalTo: start, toGranularity: .month)
            }
        }.count
        guard monthsWithData == historyMonths else {
            return .notEnoughData(monthsWithData: monthsWithData, monthsNeeded: historyMonths)
        }

        let day = calendar.component(.day, from: now)
        var monthRanges = [Range<Date>]()
        var restRanges = [Range<Date>]()
        for start in historyStarts {
            guard let end = calendar.date(byAdding: .month, value: 1, to: start),
                  let length = calendar.range(of: .day, in: .month, for: start)?.count,
                  let cutoff = calendar.date(byAdding: .day, value: min(day, length), to: start)
            else { return empty }
            monthRanges.append(start..<end)
            restRanges.append(cutoff..<end)
        }

        let currentRange = currentStart..<currentEnd
        let incomeEntries = entries.filter { $0.type == .income }
        let expenseEntries = entries.filter { $0.type == .expense }

        let categories = Dictionary(grouping: expenseEntries) { $0.categoryID }
            .compactMap { id, items -> CategoryForecast? in
                let figure = makeFigure(items, current: currentRange, rests: restRanges)
                guard figure.expected > 0, let first = items.first else { return nil }
                return CategoryForecast(id: id,
                                        name: first.categoryName,
                                        colorHex: first.colorHex,
                                        iconName: first.iconName,
                                        figure: figure)
            }
            .sorted { $0.figure.expected > $1.figure.expected }

        let history = zip(historyStarts, monthRanges).map { start, range in
            MonthTotal(month: start,
                       income: sum(incomeEntries, in: range),
                       expenses: sum(expenseEntries, in: range))
        }

        return .ready(ForecastResult(
            month: currentStart,
            dayOfMonth: day,
            daysInMonth: daysInMonth,
            income: makeFigure(incomeEntries, current: currentRange, rests: restRanges),
            expenses: makeFigure(expenseEntries, current: currentRange, rests: restRanges),
            categories: categories,
            history: history))
    }

    private static func makeFigure(_ entries: [ForecastEntry],
                                   current: Range<Date>,
                                   rests: [Range<Date>]) -> ForecastFigure {
        let soFar = sum(entries, in: current)
        let restAmounts = rests.map { sum(entries, in: $0) }
        let weighted = zip(weights, restAmounts).reduce(0) { $0 + $1.0 * $1.1 } / weights.reduce(0, +)

        return ForecastFigure(soFar: soFar,
                              expected: soFar + weighted,
                              low: soFar + (restAmounts.min() ?? 0),
                              high: soFar + (restAmounts.max() ?? 0))
    }

    private static func sum(_ entries: [ForecastEntry], in range: Range<Date>) -> Double {
        entries.reduce(0) { range.contains($1.date) ? $0 + $1.amount : $0 }
    }
}
