import CoreData

enum ExpenseError: LocalizedError {
    case invalidAmount

    var errorDescription: String? {
        switch self {
        case .invalidAmount: "Enter an amount greater than zero."
        }
    }
}

struct ExpenseDraft {
    var type: TransactionType = .expense
    var amount: Double = 0
    var currencyCode: String = AppConstants.baseCurrencyCode
    var exchangeRate: Double = 1
    var date: Date = Date()
    var merchant: String = ""
    var note: String = ""
    var category: ExpenseCategory?
    var place: Place?
    var receiptImageData: Data?
}

protocol ExpenseRepositoryProtocol {
    func fetchAll() -> [Expense]
    func add(_ draft: ExpenseDraft) throws
    func update(_ expense: Expense, with draft: ExpenseDraft) throws
    func delete(_ expense: Expense) throws
}

final class CoreDataExpenseRepository: ExpenseRepositoryProtocol {
    private let persistence: PersistenceController
    private var context: NSManagedObjectContext { persistence.viewContext }

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    func fetchAll() -> [Expense] {
        let request = NSFetchRequest<Expense>(entityName: "Expense")
        request.predicate = NSPredicate(format: "isSoftDeleted == NO")
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        return (try? context.fetch(request)) ?? []
    }

    func add(_ draft: ExpenseDraft) throws {
        guard draft.amount > 0 else { throw ExpenseError.invalidAmount }
        let expense = Expense(context: context)
        expense.id = UUID()
        apply(draft, to: expense)
        try persistence.save()
    }

    func update(_ expense: Expense, with draft: ExpenseDraft) throws {
        guard draft.amount > 0 else { throw ExpenseError.invalidAmount }
        apply(draft, to: expense)
        try persistence.save()
    }

    func delete(_ expense: Expense) throws {
        expense.receiptImageData = nil
        expense.softDelete()
        try persistence.save()
    }

    private func apply(_ draft: ExpenseDraft, to expense: Expense) {
        expense.type = draft.type
        expense.amount = draft.amount
        expense.currencyCode = draft.currencyCode
        expense.exchangeRate = draft.exchangeRate
        expense.amountLKR = draft.amount * draft.exchangeRate
        expense.date = draft.date
        expense.merchant = draft.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        expense.note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        expense.category = draft.category
        expense.place = draft.place
        expense.receiptImageData = draft.receiptImageData
        expense.markEdited()
    }
}
