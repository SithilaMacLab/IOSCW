import Combine
import Foundation

enum MapPeriod: String, CaseIterable, Identifiable {
    case thisMonth
    case threeMonths
    case allTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thisMonth: "This month"
        case .threeMonths: "3 months"
        case .allTime: "All time"
        }
    }

    func startDate(now: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard let monthStart = calendar.dateInterval(of: .month, for: now)?.start else { return nil }
        switch self {
        case .thisMonth: return monthStart
        case .threeMonths: return calendar.date(byAdding: .month, value: -2, to: monthStart)
        case .allTime: return nil
        }
    }
}

final class SpendingMapViewModel: ObservableObject {
    @Published var period: MapPeriod = .thisMonth {
        didSet { if period != oldValue { recompute() } }
    }
    @Published private(set) var areas: [AreaTotal] = []
    @Published private(set) var unplacedCount = 0

    private let repository: ExpenseRepositoryProtocol
    private var transactions: [Expense] = []
    private var observer: AnyCancellable?

    init(expenses: ExpenseRepositoryProtocol) {
        repository = expenses
        reload()
        observer = observeDataChanges { [weak self] in self?.reload() }
    }

    var maxTotal: Double { areas.first?.total ?? 0 }

    func share(of area: AreaTotal) -> Double {
        maxTotal > 0 ? area.total / maxTotal : 0
    }

    func reload() {
        transactions = repository.fetchAll()
        recompute()
    }

    private func recompute() {
        let since = period.startDate()
        areas = SpendingAreas.rank(transactions, since: since)
        unplacedCount = SpendingAreas.unplacedCount(transactions, since: since)
    }
}
