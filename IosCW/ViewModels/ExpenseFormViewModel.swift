import Combine
import Foundation

final class ExpenseFormViewModel: ObservableObject {
    @Published var type: TransactionType = .expense
    @Published var amountText = ""
    @Published var date = Date()
    @Published var merchant = ""
    @Published var note = ""
    @Published var categoryID: UUID?
    @Published var errorMessage: String?

    let categories: [ExpenseCategory]
    let currencyCode: String
    private let editing: Expense?
    private let repository: ExpenseRepositoryProtocol

    init(expenses: ExpenseRepositoryProtocol,
         categories: CategoryRepositoryProtocol,
         editing: Expense? = nil) {
        repository = expenses
        self.categories = categories.fetchAll()
        self.editing = editing
        currencyCode = editing?.currencyCode ?? AppConstants.baseCurrencyCode

        if let editing {
            type = editing.type
            amountText = editing.amount.formatted(.number.grouping(.never).precision(.fractionLength(0...2)))
            date = editing.date
            merchant = editing.merchant
            note = editing.note
            categoryID = editing.category?.id
        }
    }

    var isEditing: Bool { editing != nil }

    var amount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
    }

    var canSave: Bool { (amount ?? 0) > 0 }

    func save() -> Bool {
        guard let amount else {
            errorMessage = ExpenseError.invalidAmount.localizedDescription
            return false
        }

        let draft = ExpenseDraft(
            type: type,
            amount: amount,
            currencyCode: currencyCode,
            exchangeRate: editing?.exchangeRate ?? 1,
            date: date,
            merchant: merchant,
            note: note,
            category: categories.first { $0.id == categoryID }
        )

        do {
            if let editing {
                try repository.update(editing, with: draft)
            } else {
                try repository.add(draft)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
