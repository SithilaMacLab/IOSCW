import CoreData

enum CoreDataModel {
    static let shared: NSManagedObjectModel = build()

    private static func attribute(_ name: String,
                                  _ type: NSAttributeType,
                                  defaultValue: Any? = nil,
                                  optional: Bool = false) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        attribute.defaultValue = defaultValue
        return attribute
    }

    private static func receiptImageAttribute() -> NSAttributeDescription {
        let description = attribute("receiptImageData", .binaryDataAttributeType, optional: true)
        description.allowsExternalBinaryDataStorage = true
        return description
    }

    private static func syncAttributes() -> [NSAttributeDescription] {
        [
            attribute("id", .UUIDAttributeType),
            attribute("lastEdited", .dateAttributeType, defaultValue: Date(timeIntervalSince1970: 0)),
            attribute("syncStateRaw", .stringAttributeType, defaultValue: SyncState.pending.rawValue),
            attribute("isSoftDeleted", .booleanAttributeType, defaultValue: false)
        ]
    }

    private static func toOne(_ name: String, to destination: NSEntityDescription) -> NSRelationshipDescription {
        let relationship = NSRelationshipDescription()
        relationship.name = name
        relationship.destinationEntity = destination
        relationship.minCount = 0
        relationship.maxCount = 1
        relationship.isOptional = true
        relationship.deleteRule = .nullifyDeleteRule
        return relationship
    }

    private static func toMany(_ name: String, to destination: NSEntityDescription) -> NSRelationshipDescription {
        let relationship = NSRelationshipDescription()
        relationship.name = name
        relationship.destinationEntity = destination
        relationship.minCount = 0
        relationship.maxCount = 0
        relationship.isOptional = true
        relationship.deleteRule = .nullifyDeleteRule
        return relationship
    }

    private static func build() -> NSManagedObjectModel {
        let category = NSEntityDescription()
        category.name = "ExpenseCategory"
        category.managedObjectClassName = NSStringFromClass(ExpenseCategory.self)

        let expense = NSEntityDescription()
        expense.name = "Expense"
        expense.managedObjectClassName = NSStringFromClass(Expense.self)

        let budget = NSEntityDescription()
        budget.name = "Budget"
        budget.managedObjectClassName = NSStringFromClass(Budget.self)

        let categoryExpenses = toMany("expenses", to: expense)
        let expenseCategory = toOne("category", to: category)
        categoryExpenses.inverseRelationship = expenseCategory
        expenseCategory.inverseRelationship = categoryExpenses

        let categoryBudgets = toMany("budgets", to: budget)
        let budgetCategory = toOne("category", to: category)
        categoryBudgets.inverseRelationship = budgetCategory
        budgetCategory.inverseRelationship = categoryBudgets

        category.properties = syncAttributes() + [
            attribute("name", .stringAttributeType, defaultValue: ""),
            attribute("iconName", .stringAttributeType, defaultValue: "tag.fill"),
            attribute("colorHex", .stringAttributeType, defaultValue: "#8E8E93"),
            attribute("isDefault", .booleanAttributeType, defaultValue: false),
            categoryExpenses,
            categoryBudgets
        ]

        expense.properties = syncAttributes() + [
            attribute("amount", .doubleAttributeType, defaultValue: 0.0),
            attribute("currencyCode", .stringAttributeType, defaultValue: AppConstants.baseCurrencyCode),
            attribute("exchangeRate", .doubleAttributeType, defaultValue: 1.0),
            attribute("amountLKR", .doubleAttributeType, defaultValue: 0.0),
            attribute("date", .dateAttributeType, defaultValue: Date(timeIntervalSince1970: 0)),
            attribute("merchant", .stringAttributeType, defaultValue: ""),
            attribute("note", .stringAttributeType, defaultValue: ""),
            attribute("typeRaw", .stringAttributeType, defaultValue: TransactionType.expense.rawValue),
            attribute("latitude", .doubleAttributeType, optional: true),
            attribute("longitude", .doubleAttributeType, optional: true),
            attribute("placeName", .stringAttributeType, optional: true),
            receiptImageAttribute(),
            expenseCategory
        ]

        budget.properties = syncAttributes() + [
            attribute("monthlyLimit", .doubleAttributeType, defaultValue: 0.0),
            budgetCategory
        ]

        let model = NSManagedObjectModel()
        model.entities = [category, expense, budget]
        return model
    }
}
