import Foundation

struct TrainedSnapshot: Codable, Equatable {
    let fingerprint: String
    let trainedAt: Date
    let forecast: NextMonthForecast
}

struct NextMonthTraining: Equatable {
    let outcome: NextMonthOutcome
    let retrained: Bool
    let trainedAt: Date?
}

final class NextMonthModelStore {
    static let key = "nextMonthModel"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> TrainedSnapshot? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(TrainedSnapshot.self, from: data)
    }

    func save(_ snapshot: TrainedSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.key)
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}

protocol NextMonthModelProviding {
    @discardableResult
    func refresh() -> NextMonthTraining
}

final class NextMonthModelService: NextMonthModelProviding {
    private let expenses: ExpenseRepositoryProtocol
    private let store: NextMonthModelStore
    private let calendar: Calendar
    private let now: () -> Date

    init(expenses: ExpenseRepositoryProtocol,
         store: NextMonthModelStore = NextMonthModelStore(),
         calendar: Calendar = .current,
         now: @escaping () -> Date = Date.init) {
        self.expenses = expenses
        self.store = store
        self.calendar = calendar
        self.now = now
    }

    @discardableResult
    func refresh() -> NextMonthTraining {
        let current = now()
        let entries = expenses.fetchAll().map { ForecastEntry($0) }
        let fingerprint = NextMonthPredictor.fingerprint(entries, now: current, calendar: calendar)

        if let saved = store.load(), saved.fingerprint == fingerprint {
            return NextMonthTraining(outcome: .ready(saved.forecast), retrained: false, trainedAt: saved.trainedAt)
        }

        let outcome = NextMonthPredictor.train(entries, now: current, calendar: calendar)
        guard case .ready(let forecast) = outcome else {
            store.clear()
            return NextMonthTraining(outcome: outcome, retrained: true, trainedAt: nil)
        }

        store.save(TrainedSnapshot(fingerprint: fingerprint, trainedAt: current, forecast: forecast))
        return NextMonthTraining(outcome: outcome, retrained: true, trainedAt: current)
    }
}
