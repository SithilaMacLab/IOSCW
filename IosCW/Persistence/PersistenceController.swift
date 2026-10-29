import CoreData

extension Notification.Name {
    static let pocketlensDataDidChange = Notification.Name("PocketlensDataDidChange")
}

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext { container.viewContext }

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Pocketlens", managedObjectModel: CoreDataModel.shared)

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        var loadError = Self.loadStores(of: container)

        if let error = loadError, !inMemory, Self.isIncompatibleStore(error),
           let url = container.persistentStoreDescriptions.first?.url {
            print("Rebuilding the local store, it was made by an older version of the model: \(error)")
            try? container.persistentStoreCoordinator.destroyPersistentStore(at: url,
                                                                            ofType: NSSQLiteStoreType,
                                                                            options: nil)
            Self.forgetPullHistory()
            loadError = Self.loadStores(of: container)
        }

        if let loadError {
            fatalError("Could not load the Core Data store: \(loadError)")
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func save(notify: Bool = true) throws {
        guard viewContext.hasChanges else { return }
        do {
            try viewContext.save()
        } catch {
            viewContext.rollback()
            throw error
        }
        if notify {
            NotificationCenter.default.post(name: .pocketlensDataDidChange, object: nil)
        }
    }

    func wipeAll() throws {
        for name in ["Expense", "Budget", "ExpenseCategory"] {
            let request = NSFetchRequest<NSManagedObject>(entityName: name)
            for object in try viewContext.fetch(request) {
                viewContext.delete(object)
            }
        }
        try save()
    }

    private static func loadStores(of container: NSPersistentContainer) -> NSError? {
        var failure: NSError?
        container.loadPersistentStores { _, error in
            if let error {
                failure = error as NSError
            }
        }
        return failure
    }

    private static func isIncompatibleStore(_ error: NSError) -> Bool {
        let codes: Set<Int> = [134100, 134110, 134130, 134140]
        if error.domain == NSCocoaErrorDomain, codes.contains(error.code) {
            return true
        }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isIncompatibleStore(underlying)
        }
        return false
    }

    private static func forgetPullHistory() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("syncLastPull.") {
            defaults.removeObject(forKey: key)
        }
    }
}
