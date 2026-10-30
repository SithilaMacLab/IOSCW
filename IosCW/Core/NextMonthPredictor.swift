import Foundation

enum PredictorModel: String, Codable, CaseIterable, Equatable {
    case weighted3
    case mean3
    case last
    case smoothing
    case trend

    var title: String {
        switch self {
        case .weighted3: "Weighted average"
        case .mean3: "3-month average"
        case .last: "Same as last month"
        case .smoothing: "Smoothed level"
        case .trend: "Trend line"
        }
    }
}

enum LearningPhase: String, Codable, Equatable {
    case basic
    case early
    case learned

    init(months: Int) {
        switch months {
        case ..<4: self = .basic
        case ..<6: self = .early
        default: self = .learned
        }
    }
}

struct SeriesForecast: Codable, Equatable {
    let value: Double
    let model: PredictorModel?
    let error: Double?
    let backtestPoints: Int
    let low: Double
    let high: Double
}

struct CategoryPrediction: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let colorHex: String
    let iconName: String
    let forecast: SeriesForecast
    let lastMonth: Double
}

struct NextMonthForecast: Codable, Equatable {
    let month: Date
    let monthsOfHistory: Int
    let phase: LearningPhase
    let income: SeriesForecast
    let expenses: SeriesForecast
    let categories: [CategoryPrediction]

    var leftOver: Double { income.value - expenses.value }
}

enum NextMonthOutcome: Equatable {
    case notEnoughData(monthsWithData: Int, monthsNeeded: Int)
    case ready(NextMonthForecast)
}

enum NextMonthPredictor {
    static let minimumMonths = 3
    static let learningMonths = 6
    static let maxHistoryMonths = 24

    private static let weights: [Double] = [1, 2, 3]
    private static let switchMargin = 0.95
    private static let trendWindow = 6
    private static let trendShrink = 1.25
    private static let minimumSpread = 0.05

    static var empty: NextMonthOutcome {
        .notEnoughData(monthsWithData: 0, monthsNeeded: minimumMonths)
    }

    static func train(_ entries: [ForecastEntry],
                      now: Date = Date(),
                      calendar: Calendar = .current) -> NextMonthOutcome {
        guard let currentStart = calendar.dateInterval(of: .month, for: now)?.start,
              let nextStart = calendar.date(byAdding: .month, value: 1, to: currentStart)
        else { return empty }

        let currentIndex = monthIndex(currentStart, calendar: calendar)

        var offsetsWithExpense = Set<Int>()
        var oldest = 0
        for entry in entries where entry.type == .expense {
            let offset = currentIndex - monthIndex(entry.date, calendar: calendar)
            guard offset >= 1, offset <= maxHistoryMonths else { continue }
            offsetsWithExpense.insert(offset)
            oldest = max(oldest, offset)
        }

        let withData = (1...minimumMonths).filter { offsetsWithExpense.contains($0) }.count
        guard withData == minimumMonths else {
            return .notEnoughData(monthsWithData: withData, monthsNeeded: minimumMonths)
        }

        let months = oldest
        var categorySeries = [String: [Double]]()
        var samples = [String: ForecastEntry]()
        var incomeSeries = [Double](repeating: 0, count: months)

        for entry in entries {
            let offset = currentIndex - monthIndex(entry.date, calendar: calendar)
            guard offset >= 1, offset <= months else { continue }
            let position = months - offset

            switch entry.type {
            case .income:
                incomeSeries[position] += entry.amount
            case .expense:
                categorySeries[entry.categoryID, default: [Double](repeating: 0, count: months)][position] += entry.amount
                if samples[entry.categoryID] == nil {
                    samples[entry.categoryID] = entry
                }
            }
        }

        var predictions = [CategoryPrediction]()
        var allSeries = [[Double]]()
        var allModels = [PredictorModel]()

        for id in categorySeries.keys.sorted() {
            guard let series = categorySeries[id], let sample = samples[id] else { continue }
            let result = fit(series)
            allSeries.append(series)
            allModels.append(result.model ?? .weighted3)
            guard result.value >= 1 else { continue }
            predictions.append(CategoryPrediction(id: id,
                                                  name: sample.categoryName,
                                                  colorHex: sample.colorHex,
                                                  iconName: sample.iconName,
                                                  forecast: result,
                                                  lastMonth: series[months - 1]))
        }
        predictions.sort { $0.forecast.value > $1.forecast.value }

        let totalValue = predictions.reduce(0) { $0 + $1.forecast.value }
        let totalSeries = (0..<months).map { index in allSeries.reduce(0) { $0 + $1[index] } }
        let combined = combinedError(series: allSeries, models: allModels)
        let totalRange = spread(value: totalValue, error: combined.error, recent: totalSeries)
        let expenses = SeriesForecast(value: totalValue,
                                      model: nil,
                                      error: combined.error,
                                      backtestPoints: combined.points,
                                      low: max(totalRange.low, 0),
                                      high: totalRange.high)

        return .ready(NextMonthForecast(month: nextStart,
                                        monthsOfHistory: months,
                                        phase: LearningPhase(months: months),
                                        income: fit(incomeSeries),
                                        expenses: expenses,
                                        categories: predictions))
    }

    static func fingerprint(_ entries: [ForecastEntry],
                            now: Date = Date(),
                            calendar: Calendar = .current) -> String {
        let currentIndex = monthIndex(now, calendar: calendar)
        var count = 0
        var expense = 0.0
        var income = 0.0

        for entry in entries {
            let offset = currentIndex - monthIndex(entry.date, calendar: calendar)
            guard offset >= 1, offset <= maxHistoryMonths else { continue }
            count += 1
            if entry.type == .expense {
                expense += entry.amount
            } else {
                income += entry.amount
            }
        }
        return "\(currentIndex)|\(count)|\(Int((expense * 100).rounded()))|\(Int((income * 100).rounded()))"
    }

    static func fit(_ series: [Double]) -> SeriesForecast {
        let baseline = backtest(.weighted3, series)
        var chosen = PredictorModel.weighted3
        var chosenError = baseline.error

        if series.count >= learningMonths, let baselineError = baseline.error {
            for candidate in PredictorModel.allCases where candidate != .weighted3 {
                guard let error = backtest(candidate, series).error else { continue }
                if error < baselineError * switchMargin, error < (chosenError ?? .infinity) {
                    chosen = candidate
                    chosenError = error
                }
            }
        }

        let value = max(predict(chosen, history: series), 0)
        let range = spread(value: value, error: chosenError, recent: series)
        return SeriesForecast(value: value,
                              model: chosen,
                              error: chosenError,
                              backtestPoints: baseline.points,
                              low: max(range.low, 0),
                              high: range.high)
    }

    static func predict(_ model: PredictorModel, history: [Double]) -> Double {
        guard !history.isEmpty else { return 0 }

        switch model {
        case .last:
            return history[history.count - 1]
        case .mean3:
            let tail = history.suffix(3)
            return tail.reduce(0, +) / Double(tail.count)
        case .weighted3:
            let tail = Array(history.suffix(3))
            let used = Array(weights.suffix(tail.count))
            let total = zip(tail, used).reduce(0) { $0 + $1.0 * $1.1 }
            return total / used.reduce(0, +)
        case .smoothing:
            var level = history[0]
            for value in history.dropFirst() {
                level = 0.5 * value + 0.5 * level
            }
            return level
        case .trend:
            return trendForecast(Array(history.suffix(trendWindow)))
        }
    }

    static func backtest(_ model: PredictorModel, _ series: [Double]) -> (error: Double?, points: Int) {
        guard series.count > minimumMonths else { return (nil, 0) }

        var absoluteError = 0.0
        var actualSum = 0.0
        for index in minimumMonths..<series.count {
            let predicted = max(predict(model, history: Array(series[0..<index])), 0)
            absoluteError += abs(predicted - series[index])
            actualSum += series[index]
        }
        let points = series.count - minimumMonths
        return (actualSum > 0 ? absoluteError / actualSum : nil, points)
    }

    private static func trendForecast(_ window: [Double]) -> Double {
        let count = Double(window.count)
        let meanY = window.reduce(0, +) / count
        guard window.count >= 3 else { return meanY }

        let meanX = (count - 1) / 2
        var sxx = 0.0
        var sxy = 0.0
        for (index, value) in window.enumerated() {
            let dx = Double(index) - meanX
            sxx += dx * dx
            sxy += dx * (value - meanY)
        }
        let slope = sxy / (sxx * trendShrink)
        let next = meanY + slope * (count - meanX)
        return min(max(next, 0), (window.max() ?? 0) * 1.5)
    }

    private static func combinedError(series: [[Double]],
                                      models: [PredictorModel]) -> (error: Double?, points: Int) {
        guard let length = series.first?.count, length > minimumMonths else { return (nil, 0) }

        var absoluteError = 0.0
        var actualSum = 0.0
        for index in minimumMonths..<length {
            var predicted = 0.0
            var actual = 0.0
            for (values, model) in zip(series, models) {
                predicted += max(predict(model, history: Array(values[0..<index])), 0)
                actual += values[index]
            }
            absoluteError += abs(predicted - actual)
            actualSum += actual
        }
        return (actualSum > 0 ? absoluteError / actualSum : nil, length - minimumMonths)
    }

    private static func spread(value: Double, error: Double?, recent: [Double]) -> (low: Double, high: Double) {
        if let error {
            let width = max(error, minimumSpread)
            return (value * (1 - width), value * (1 + width))
        }
        let tail = recent.suffix(3)
        return (min(tail.min() ?? value, value), max(tail.max() ?? value, value))
    }

    private static func monthIndex(_ date: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return (parts.year ?? 0) * 12 + (parts.month ?? 1) - 1
    }
}
