import CoreData

enum SyncMapper {
    static func record(for object: any SyncTracked) -> SyncRecord? {
        switch object {
        case let category as ExpenseCategory:
            return SyncRecord(
                kind: .categories,
                id: category.id,
                lastEdited: category.lastEdited,
                isDeleted: category.isSoftDeleted,
                fields: [
                    "name": category.name,
                    "iconName": category.iconName,
                    "colorHex": category.colorHex,
                    "isDefault": category.isDefault
                ])

        case let budget as Budget:
            var fields: [String: Any] = ["monthlyLimit": budget.monthlyLimit]
            if let categoryID = budget.category?.id {
                fields["categoryID"] = categoryID.uuidString
            }
            return SyncRecord(
                kind: .budgets,
                id: budget.id,
                lastEdited: budget.lastEdited,
                isDeleted: budget.isSoftDeleted,
                fields: fields)

        case let expense as Expense:
            var fields: [String: Any] = [
                "amount": expense.amount,
                "currencyCode": expense.currencyCode,
                "exchangeRate": expense.exchangeRate,
                "amountLKR": expense.amountLKR,
                "date": expense.date,
                "merchant": expense.merchant,
                "note": expense.note,
                "type": expense.typeRaw
            ]
            if let categoryID = expense.category?.id {
                fields["categoryID"] = categoryID.uuidString
            }
            return SyncRecord(
                kind: .expenses,
                id: expense.id,
                lastEdited: expense.lastEdited,
                isDeleted: expense.isSoftDeleted,
                fields: fields)

        default:
            return nil
        }
    }

    static func apply(_ record: SyncRecord, to object: NSManagedObject, in context: NSManagedObjectContext) {
        switch object {
        case let category as ExpenseCategory:
            category.id = record.id
            category.name = record.string("name") ?? category.name
            category.iconName = record.string("iconName") ?? category.iconName
            category.colorHex = record.string("colorHex") ?? category.colorHex
            category.isDefault = record.bool("isDefault") ?? category.isDefault
            finish(category, with: record)

        case let budget as Budget:
            budget.id = record.id
            budget.monthlyLimit = record.double("monthlyLimit") ?? budget.monthlyLimit
            budget.category = category(withID: record.string("categoryID"), in: context)
            finish(budget, with: record)

        case let expense as Expense:
            expense.id = record.id
            expense.amount = record.double("amount") ?? expense.amount
            expense.currencyCode = record.string("currencyCode") ?? expense.currencyCode
            expense.exchangeRate = record.double("exchangeRate") ?? expense.exchangeRate
            expense.amountLKR = record.double("amountLKR") ?? expense.amountLKR
            expense.date = record.date("date") ?? expense.date
            expense.merchant = record.string("merchant") ?? expense.merchant
            expense.note = record.string("note") ?? expense.note
            expense.typeRaw = record.string("type") ?? expense.typeRaw
            expense.category = category(withID: record.string("categoryID"), in: context)
            finish(expense, with: record)

        default:
            break
        }
    }

    private static func finish(_ object: any SyncTracked, with record: SyncRecord) {
        object.lastEdited = record.lastEdited
        object.isSoftDeleted = false
        object.syncState = .synced
    }

    private static func category(withID idString: String?, in context: NSManagedObjectContext) -> ExpenseCategory? {
        guard let idString, let id = UUID(uuidString: idString) else { return nil }
        let request = NSFetchRequest<ExpenseCategory>(entityName: "ExpenseCategory")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first
    }
}
