import Foundation

struct ExpenseFilter: Equatable {
    var searchText = ""
    var type: TransactionType?
    var categoryID: UUID?
    var startDate: Date?
    var endDate: Date?
    var minAmount: Double?
    var maxAmount: Double?

    var hasActiveFilters: Bool {
        type != nil || categoryID != nil || startDate != nil || endDate != nil
            || minAmount != nil || maxAmount != nil
    }

    var isEmpty: Bool {
        !hasActiveFilters && searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    mutating func clearFilters() {
        type = nil
        categoryID = nil
        startDate = nil
        endDate = nil
        minAmount = nil
        maxAmount = nil
    }

    func matches(_ expense: Expense, calendar: Calendar = .current) -> Bool {
        if let type, expense.type != type { return false }
        if let categoryID, expense.category?.id != categoryID { return false }

        if let startDate, expense.date < calendar.startOfDay(for: startDate) { return false }
        if let endDate,
           let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)),
           expense.date >= endOfDay { return false }

        if let minAmount, expense.amountLKR < minAmount { return false }
        if let maxAmount, expense.amountLKR > maxAmount { return false }

        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            let haystack = [expense.merchant, expense.note, expense.category?.name ?? ""]
            if !haystack.contains(where: { $0.localizedCaseInsensitiveContains(query) }) { return false }
        }
        return true
    }
}

enum ExpenseSort: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case highestAmount
    case lowestAmount

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: "Newest first"
        case .oldest: "Oldest first"
        case .highestAmount: "Highest amount"
        case .lowestAmount: "Lowest amount"
        }
    }

    func sorted(_ expenses: [Expense]) -> [Expense] {
        switch self {
        case .newest: expenses.sorted { $0.date > $1.date }
        case .oldest: expenses.sorted { $0.date < $1.date }
        case .highestAmount: expenses.sorted { $0.amountLKR > $1.amountLKR }
        case .lowestAmount: expenses.sorted { $0.amountLKR < $1.amountLKR }
        }
    }
}
