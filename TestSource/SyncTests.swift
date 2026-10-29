import CoreData
import Foundation
import Testing
@testable import IosCW

@MainActor
struct SyncRecordTests {
    @Test("A record survives being turned into cloud data and back")
    func payloadRoundTrip() throws {
        let id = UUID()
        let edited = TestClock.date(2026, 10, 5)
        let record = SyncRecord(kind: .expenses, id: id, lastEdited: edited, isDeleted: false,
                                fields: ["amount": 1250.0, "merchant": "Keells"])

        let payload = record.payload
        #expect(payload["isDeleted"] as? Bool == false)
        #expect(payload["lastEdited"] as? Date == edited)

        let restored = try #require(SyncRecord(kind: .expenses, documentID: id.uuidString, data: payload))
        #expect(restored.id == id)
        #expect(restored.lastEdited == edited)
        #expect(restored.isDeleted == false)
        #expect(restored.double("amount") == 1250)
        #expect(restored.string("merchant") == "Keells")
        #expect(restored.fields["lastEdited"] == nil)
    }

    @Test("A cloud document without a valid id or edit time is ignored")
    func invalidDocuments() {
        #expect(SyncRecord(kind: .expenses, documentID: "not-a-uuid", data: ["lastEdited": Date()]) == nil)
        #expect(SyncRecord(kind: .expenses, documentID: UUID().uuidString, data: ["amount": 5]) == nil)
    }

    @Test("Whole numbers from the cloud are read as doubles")
    func integerAmounts() {
        let record = SyncRecord(kind: .budgets, id: UUID(), lastEdited: Date(), isDeleted: false,
                                fields: ["monthlyLimit": 5000, "big": Int64(7)])
        #expect(record.double("monthlyLimit") == 5000)
        #expect(record.double("big") == 7)
        #expect(record.double("missing") == nil)
    }

    @Test("Deterministic ids are stable, different per name and valid version 5 ids")
    func deterministicIDs() {
        let first = UUID.deterministic(from: "pocketlens.default.Groceries")
        let again = UUID.deterministic(from: "pocketlens.default.Groceries")
        let other = UUID.deterministic(from: "pocketlens.default.Transport")

        #expect(first == again)
        #expect(first != other)
        #expect(first.uuid.6 >> 4 == 5)
        #expect(first.uuid.8 & 0xC0 == 0x80)
    }

    @Test("Two phones create the same default categories")
    func defaultCategoriesMatchAcrossDevices() throws {
        let phoneA = PersistenceController(inMemory: true)
        let phoneB = PersistenceController(inMemory: true)
        let categoriesA = CoreDataCategoryRepository(persistence: phoneA)
        let categoriesB = CoreDataCategoryRepository(persistence: phoneB)
        try categoriesA.seedDefaultsIfNeeded()
        try categoriesB.seedDefaultsIfNeeded()

        let idsA = Set(categoriesA.fetchAll().map(\.id))
        let idsB = Set(categoriesB.fetchAll().map(\.id))

        #expect(idsA.count == CoreDataCategoryRepository.defaults.count)
        #expect(idsA == idsB)
        #expect(categoriesA.fetchAll().allSatisfy { $0.syncState == .synced })
    }
}

@MainActor
struct SyncMapperTests {
    @Test("An expense with a place is mapped to a record and rebuilt on another phone")
    func expenseRoundTrip() throws {
        let phoneA = PersistenceController(inMemory: true)
        let categoriesA = CoreDataCategoryRepository(persistence: phoneA)
        let expensesA = CoreDataExpenseRepository(persistence: phoneA)
        try categoriesA.seedDefaultsIfNeeded()
        let groceries = try #require(categoriesA.fetchAll().first { $0.name == "Groceries" })

        try expensesA.add(ExpenseDraft(
            type: .expense,
            amount: 12.5,
            currencyCode: "USD",
            exchangeRate: 300,
            date: TestClock.date(2026, 10, 5),
            merchant: "Amazon",
            note: "headphones",
            category: groceries,
            place: Place(latitude: 6.93, longitude: 79.84, name: "Fort, Colombo"),
            receiptImageData: Data([1, 2, 3])))
        let original = try #require(expensesA.fetchAll().first)
        let record = try #require(SyncMapper.record(for: original))

        #expect(record.kind == .expenses)
        #expect(record.fields["placeName"] as? String == "Fort, Colombo")
        #expect(record.fields["receiptImageData"] == nil)

        let phoneB = PersistenceController(inMemory: true)
        let categoriesB = CoreDataCategoryRepository(persistence: phoneB)
        try categoriesB.seedDefaultsIfNeeded()
        let object = NSEntityDescription.insertNewObject(forEntityName: "Expense", into: phoneB.viewContext)
        SyncMapper.apply(record, to: object, in: phoneB.viewContext)
        let copy = try #require(object as? Expense)

        #expect(copy.id == original.id)
        #expect(copy.amount == 12.5)
        #expect(copy.currencyCode == "USD")
        #expect(copy.exchangeRate == 300)
        #expect(copy.amountLKR == 3750)
        #expect(copy.merchant == "Amazon")
        #expect(copy.note == "headphones")
        #expect(copy.type == .expense)
        #expect(copy.date == TestClock.date(2026, 10, 5))
        #expect(copy.place?.name == "Fort, Colombo")
        #expect(copy.category?.name == "Groceries")
        #expect(copy.syncState == .synced)
        #expect(copy.lastEdited == original.lastEdited)
        #expect(copy.receiptImageData == nil)
    }

    @Test("A cloud record without a place clears the place")
    func missingPlaceClearsPlace() throws {
        let persistence = PersistenceController(inMemory: true)
        let expenses = CoreDataExpenseRepository(persistence: persistence)
        try expenses.add(ExpenseDraft(amount: 100, place: Place(latitude: 1, longitude: 2, name: "Somewhere")))
        let expense = try #require(expenses.fetchAll().first)
        #expect(expense.place != nil)

        let record = SyncRecord(kind: .expenses, id: expense.id, lastEdited: Date().addingTimeInterval(10),
                                isDeleted: false, fields: ["amount": 100.0])
        SyncMapper.apply(record, to: expense, in: persistence.viewContext)

        #expect(expense.place == nil)
    }

    @Test("Budgets keep their category link")
    func budgetRoundTrip() throws {
        let persistence = PersistenceController(inMemory: true)
        let categories = CoreDataCategoryRepository(persistence: persistence)
        let budgets = CoreDataBudgetRepository(persistence: persistence)
        try categories.seedDefaultsIfNeeded()
        let transport = try #require(categories.fetchAll().first { $0.name == "Transport" })
        try budgets.setLimit(15_000, for: transport)
        let budget = try #require(budgets.fetchAll().first)

        let record = try #require(SyncMapper.record(for: budget))
        #expect(record.kind == .budgets)
        #expect(record.double("monthlyLimit") == 15_000)
        #expect(record.string("categoryID") == transport.id.uuidString)
    }
}

@MainActor
struct SyncFixture {
    let persistence: PersistenceController
    let categories: CoreDataCategoryRepository
    let expenses: CoreDataExpenseRepository
    let auth: DevAuthService
    let remote: FakeRemote
    let network: NetworkMonitor
    let engine: SyncEngine

    init(online: Bool = true, email: String = "alice@example.com") async throws {
        let persistence = PersistenceController(inMemory: true)
        let categories = CoreDataCategoryRepository(persistence: persistence)
        try categories.seedDefaultsIfNeeded()
        let auth = DevAuthService(defaults: isolatedDefaults())
        try await auth.signIn(email: email, password: "Password1")
        let remote = FakeRemote()
        let network = NetworkMonitor(initiallyOnline: online, monitorsSystem: false)

        self.persistence = persistence
        self.categories = categories
        self.expenses = CoreDataExpenseRepository(persistence: persistence)
        self.auth = auth
        self.remote = remote
        self.network = network
        self.engine = SyncEngine(persistence: persistence,
                                 remote: remote,
                                 auth: auth,
                                 network: network,
                                 categories: categories,
                                 defaults: isolatedDefaults())
    }

    func addExpense(amount: Double = 500) throws -> Expense {
        let groceries = try #require(categories.fetchAll().first { $0.name == "Groceries" })
        try expenses.add(ExpenseDraft(amount: amount, merchant: "Keells", category: groceries))
        return try #require(expenses.fetchAll().first)
    }

    func expenseRowCount() throws -> Int {
        try persistence.viewContext.count(for: NSFetchRequest<NSManagedObject>(entityName: "Expense"))
    }
}

@MainActor
@Suite(.serialized)
struct SyncEngineTests {
    @Test("Pending changes are uploaded and then marked as synced")
    func pushesPendingChanges() async throws {
        let fixture = try await SyncFixture()
        let expense = try fixture.addExpense()
        #expect(expense.syncState == .pending)

        await fixture.engine.syncAndWait()

        let uploaded = fixture.remote.pushed.filter { $0.kind == .expenses }
        #expect(uploaded.count == 1)
        #expect(uploaded.first?.id == expense.id)
        #expect(expense.syncState == .synced)
        #expect(fixture.engine.pendingCount == 0)
        #expect(fixture.engine.statusText == "Synced")
    }

    @Test("The default categories are not uploaded again")
    func defaultsAreNotPushed() async throws {
        let fixture = try await SyncFixture()

        await fixture.engine.syncAndWait()

        #expect(fixture.remote.pushed.isEmpty)
    }

    @Test("A newer change from the cloud replaces the local copy")
    func newerCloudChangeWins() async throws {
        let fixture = try await SyncFixture()
        let expense = try fixture.addExpense(amount: 500)
        await fixture.engine.syncAndWait()

        let original = try #require(fixture.remote.stored[.expenses]?[expense.id])
        var fields = original.fields
        fields["amount"] = 999.0
        fixture.remote.put(SyncRecord(kind: .expenses, id: original.id,
                                      lastEdited: original.lastEdited.addingTimeInterval(60),
                                      isDeleted: false, fields: fields))

        await fixture.engine.syncAndWait()

        #expect(expense.amount == 999)
        #expect(expense.syncState == .synced)
    }

    @Test("An older change from the cloud does not overwrite a newer local copy")
    func olderCloudChangeIgnored() async throws {
        let fixture = try await SyncFixture()
        let expense = try fixture.addExpense(amount: 500)
        await fixture.engine.syncAndWait()

        let original = try #require(fixture.remote.stored[.expenses]?[expense.id])
        var fields = original.fields
        fields["amount"] = 1.0
        fixture.remote.put(SyncRecord(kind: .expenses, id: original.id,
                                      lastEdited: original.lastEdited.addingTimeInterval(-60),
                                      isDeleted: false, fields: fields))

        let freshEngine = SyncEngine(persistence: fixture.persistence,
                                     remote: fixture.remote,
                                     auth: fixture.auth,
                                     network: fixture.network,
                                     categories: fixture.categories,
                                     defaults: isolatedDefaults())
        await freshEngine.syncAndWait()

        #expect(expense.amount == 500)
    }

    @Test("A deletion made on another phone removes the local copy")
    func cloudDeletionRemovesLocalCopy() async throws {
        let fixture = try await SyncFixture()
        let expense = try fixture.addExpense()
        await fixture.engine.syncAndWait()

        let original = try #require(fixture.remote.stored[.expenses]?[expense.id])
        fixture.remote.put(SyncRecord(kind: .expenses, id: original.id,
                                      lastEdited: original.lastEdited.addingTimeInterval(60),
                                      isDeleted: true, fields: [:]))

        await fixture.engine.syncAndWait()

        #expect(fixture.expenses.fetchAll().isEmpty)
        #expect(try fixture.expenseRowCount() == 0)
    }

    @Test("A local deletion is uploaded as a tombstone and then removed for good")
    func localDeletionUploadsTombstone() async throws {
        let fixture = try await SyncFixture()
        let expense = try fixture.addExpense()
        await fixture.engine.syncAndWait()

        try fixture.expenses.delete(expense)
        #expect(try fixture.expenseRowCount() == 1)

        await fixture.engine.syncAndWait()

        let last = try #require(fixture.remote.pushed.last)
        #expect(last.kind == .expenses)
        #expect(last.isDeleted)
        #expect(try fixture.expenseRowCount() == 0)
    }

    @Test("Offline changes wait, then upload when the connection returns")
    func offlineQueue() async throws {
        let fixture = try await SyncFixture(online: false)
        _ = try fixture.addExpense()

        await fixture.engine.syncAndWait()

        #expect(fixture.engine.statusText == "Offline")
        #expect(fixture.remote.pushed.isEmpty)
        #expect(fixture.remote.fetchCount == 0)
        #expect(fixture.engine.pendingCount == 1)

        fixture.network.setOnline(true)
        let uploaded = await waitUntil {
            fixture.remote.pushed.contains { $0.kind == .expenses } && fixture.engine.pendingCount == 0
        }

        #expect(uploaded)
    }

    @Test("A remote failure keeps the change pending and reports a problem")
    func failureKeepsChangesPending() async throws {
        let fixture = try await SyncFixture()
        let failing = FailingRemote()
        let engine = SyncEngine(persistence: fixture.persistence,
                                remote: failing,
                                auth: fixture.auth,
                                network: fixture.network,
                                categories: fixture.categories,
                                defaults: isolatedDefaults())
        let expense = try fixture.addExpense()

        await engine.syncAndWait()

        #expect(expense.syncState == .pending)
        #expect(engine.pendingCount == 1)
        #expect(engine.statusText == "Sync problem")
    }

    @Test("Signing in as a different user clears the previous user's data")
    func differentUserWipesLocalData() async throws {
        let fixture = try await SyncFixture(email: "alice@example.com")
        await fixture.engine.sessionChangedAndWait()
        _ = try fixture.addExpense()
        #expect(fixture.expenses.fetchAll().count == 1)

        try fixture.auth.signOut()
        try await fixture.auth.signIn(email: "bob@example.com", password: "Password1")
        await fixture.engine.sessionChangedAndWait()

        #expect(fixture.expenses.fetchAll().isEmpty)
        #expect(fixture.categories.fetchAll().count == CoreDataCategoryRepository.defaults.count)
    }

    @Test("Signing in again as the same user keeps the data")
    func sameUserKeepsData() async throws {
        let fixture = try await SyncFixture(email: "alice@example.com")
        await fixture.engine.sessionChangedAndWait()
        _ = try fixture.addExpense()

        try fixture.auth.signOut()
        try await fixture.auth.signIn(email: "alice@example.com", password: "Password1")
        await fixture.engine.sessionChangedAndWait()

        #expect(fixture.expenses.fetchAll().count == 1)
    }

    @Test("Signed out means nothing is uploaded")
    func signedOutDoesNotSync() async throws {
        let fixture = try await SyncFixture()
        _ = try fixture.addExpense()
        try fixture.auth.signOut()

        await fixture.engine.syncAndWait()

        #expect(fixture.remote.pushed.isEmpty)
        #expect(fixture.remote.fetchCount == 0)
    }
}

@MainActor
final class FailingRemote: RemoteStoreProtocol {
    struct Down: Error {}

    func push(_ records: [SyncRecord], userID: String) async throws { throw Down() }
    func fetch(_ kind: SyncKind, since: Date?, userID: String) async throws -> [SyncRecord] { throw Down() }
    func deleteAll(userID: String) async throws { throw Down() }
}
