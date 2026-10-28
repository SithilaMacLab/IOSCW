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

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Could not load the Core Data store: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func save() throws {
        guard viewContext.hasChanges else { return }
        do {
            try viewContext.save()
        } catch {
            viewContext.rollback()
            throw error
        }
        NotificationCenter.default.post(name: .pocketlensDataDidChange, object: nil)
    }
}
