import CoreData

enum CategoryError: LocalizedError {
    case emptyName
    case duplicateName
    case cannotDeleteDefault

    var errorDescription: String? {
        switch self {
        case .emptyName: "Please enter a category name."
        case .duplicateName: "A category with that name already exists."
        case .cannotDeleteDefault: "Default categories can't be deleted."
        }
    }
}

protocol CategoryRepositoryProtocol {
    func fetchAll() -> [ExpenseCategory]
    func add(name: String, iconName: String, colorHex: String) throws
    func update(_ category: ExpenseCategory, name: String, iconName: String, colorHex: String) throws
    func delete(_ category: ExpenseCategory) throws
    func seedDefaultsIfNeeded() throws
}

final class CoreDataCategoryRepository: CategoryRepositoryProtocol {
    private let persistence: PersistenceController
    private var context: NSManagedObjectContext { persistence.viewContext }

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    static let defaults: [(name: String, icon: String, color: String)] = [
        ("Food & Dining", "fork.knife", "#FF9500"),
        ("Groceries", "cart.fill", "#34C759"),
        ("Transport", "car.fill", "#007AFF"),
        ("Shopping", "bag.fill", "#AF52DE"),
        ("Bills & Utilities", "doc.text.fill", "#5856D6"),
        ("Health", "cross.case.fill", "#FF3B30"),
        ("Entertainment", "popcorn.fill", "#FF2D55"),
        ("Education", "book.fill", "#00C7BE"),
        ("Salary", "banknote.fill", "#30B0C7"),
        ("Other", "ellipsis.circle.fill", "#8E8E93")
    ]

    func fetchAll() -> [ExpenseCategory] {
        let request = NSFetchRequest<ExpenseCategory>(entityName: "ExpenseCategory")
        request.predicate = NSPredicate(format: "isSoftDeleted == NO")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true,
                                                    selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
        return (try? context.fetch(request)) ?? []
    }

    func add(name: String, iconName: String, colorHex: String) throws {
        let cleaned = try validatedName(name, excluding: nil)
        let category = ExpenseCategory(context: context)
        category.id = UUID()
        category.name = cleaned
        category.iconName = iconName
        category.colorHex = colorHex
        category.isDefault = false
        category.markEdited()
        try persistence.save()
    }

    func update(_ category: ExpenseCategory, name: String, iconName: String, colorHex: String) throws {
        category.name = try validatedName(name, excluding: category)
        category.iconName = iconName
        category.colorHex = colorHex
        category.markEdited()
        try persistence.save()
    }

    func delete(_ category: ExpenseCategory) throws {
        guard !category.isDefault else { throw CategoryError.cannotDeleteDefault }

        for case let expense as Expense in category.expenses?.allObjects ?? [] {
            expense.category = nil
            expense.markEdited()
        }
        for case let budget as Budget in category.budgets?.allObjects ?? [] {
            budget.softDelete()
        }
        category.softDelete()
        try persistence.save()
    }

    func seedDefaultsIfNeeded() throws {
        let request = NSFetchRequest<ExpenseCategory>(entityName: "ExpenseCategory")
        request.fetchLimit = 1
        guard (try? context.count(for: request)) == 0 else { return }

        for item in Self.defaults {
            let category = ExpenseCategory(context: context)
            category.id = UUID()
            category.name = item.name
            category.iconName = item.icon
            category.colorHex = item.color
            category.isDefault = true
            category.markEdited()
        }
        try persistence.save()
    }

    private func validatedName(_ name: String, excluding current: ExpenseCategory?) throws -> String {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw CategoryError.emptyName }

        let clash = fetchAll().contains {
            $0 != current && $0.name.caseInsensitiveCompare(cleaned) == .orderedSame
        }
        guard !clash else { throw CategoryError.duplicateName }
        return cleaned
    }
}
