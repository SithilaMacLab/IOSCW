import CoreData

enum BudgetError: LocalizedError {
    case invalidLimit

    var errorDescription: String? {
        switch self {
        case .invalidLimit: "Enter a monthly limit greater than zero."
        }
    }
}

protocol BudgetRepositoryProtocol {
    func fetchAll() -> [Budget]
    func setLimit(_ limit: Double, for category: ExpenseCategory) throws
    func delete(_ budget: Budget) throws
}

final class CoreDataBudgetRepository: BudgetRepositoryProtocol {
    private let persistence: PersistenceController
    private var context: NSManagedObjectContext { persistence.viewContext }

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    func fetchAll() -> [Budget] {
        let request = NSFetchRequest<Budget>(entityName: "Budget")
        request.predicate = NSPredicate(format: "isSoftDeleted == NO")
        return (try? context.fetch(request)) ?? []
    }

    func setLimit(_ limit: Double, for category: ExpenseCategory) throws {
        guard limit > 0 else { throw BudgetError.invalidLimit }

        let budget = fetchAll().first { $0.category == category } ?? {
            let new = Budget(context: context)
            new.id = UUID()
            new.category = category
            return new
        }()
        budget.monthlyLimit = limit
        budget.markEdited()
        try persistence.save()
    }

    func delete(_ budget: Budget) throws {
        budget.softDelete()
        try persistence.save()
    }
}
