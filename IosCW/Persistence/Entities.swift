import CoreData

enum SyncState: String {
    case pending
    case synced
}

protocol SyncTracked: NSManagedObject {
    var lastEdited: Date { get set }
    var syncStateRaw: String { get set }
    var isSoftDeleted: Bool { get set }
}

extension SyncTracked {
    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .pending }
        set { syncStateRaw = newValue.rawValue }
    }

    func markEdited() {
        lastEdited = Date()
        syncState = .pending
    }

    func softDelete() {
        isSoftDeleted = true
        markEdited()
    }
}

@objc(ExpenseCategory)
final class ExpenseCategory: NSManagedObject, Identifiable, SyncTracked {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var iconName: String
    @NSManaged var colorHex: String
    @NSManaged var isDefault: Bool
    @NSManaged var lastEdited: Date
    @NSManaged var syncStateRaw: String
    @NSManaged var isSoftDeleted: Bool
    @NSManaged var expenses: NSSet?
    @NSManaged var budgets: NSSet?
}

@objc(Expense)
final class Expense: NSManagedObject, Identifiable, SyncTracked {
    @NSManaged var id: UUID
    @NSManaged var amount: Double
    @NSManaged var currencyCode: String
    @NSManaged var exchangeRate: Double
    @NSManaged var amountLKR: Double
    @NSManaged var date: Date
    @NSManaged var merchant: String
    @NSManaged var note: String
    @NSManaged var typeRaw: String
    @NSManaged var lastEdited: Date
    @NSManaged var syncStateRaw: String
    @NSManaged var isSoftDeleted: Bool
    @NSManaged var category: ExpenseCategory?

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }
}

@objc(Budget)
final class Budget: NSManagedObject, Identifiable, SyncTracked {
    @NSManaged var id: UUID
    @NSManaged var monthlyLimit: Double
    @NSManaged var lastEdited: Date
    @NSManaged var syncStateRaw: String
    @NSManaged var isSoftDeleted: Bool
    @NSManaged var category: ExpenseCategory?
}
