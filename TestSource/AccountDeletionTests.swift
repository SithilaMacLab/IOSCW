import Foundation
import Testing
@testable import IosCW

@MainActor
struct DeletionFixture {
    let log: EventLog
    let auth: FakeAuth
    let remote: FakeRemote
    let categories: CoreDataCategoryRepository
    let expenses: CoreDataExpenseRepository
    let service: AccountDeletionService

    init(online: Bool = true, hasRemote: Bool = true, signedIn: Bool = true) throws {
        let log = EventLog()
        let persistence = PersistenceController(inMemory: true)
        let categories = CoreDataCategoryRepository(persistence: persistence)
        try categories.seedDefaultsIfNeeded()
        let expenses = CoreDataExpenseRepository(persistence: persistence)
        guard let groceries = categories.fetchAll().first(where: { $0.name == "Groceries" }) else {
            throw TestError()
        }
        try expenses.add(ExpenseDraft(amount: 500, category: groceries))

        let auth = FakeAuth(userID: signedIn ? "user-1" : nil, log: log)
        let remote = FakeRemote()
        remote.log = log

        self.log = log
        self.auth = auth
        self.remote = remote
        self.categories = categories
        self.expenses = expenses
        self.service = AccountDeletionService(
            auth: auth,
            remote: hasRemote ? remote : nil,
            sync: FakeSync(log: log),
            persistence: persistence,
            categories: categories,
            widget: FakeWidget(log: log),
            network: NetworkMonitor(initiallyOnline: online, monitorsSystem: false))
    }
}

@MainActor
struct AccountDeletionTests {
    @Test("Everything is deleted in a safe order and the phone is cleared")
    func fullDeletion() async throws {
        let fixture = try DeletionFixture()
        #expect(fixture.expenses.fetchAll().count == 1)

        try await fixture.service.deleteEverything(password: "Password1")

        #expect(fixture.log.events == [
            "auth.reauth",
            "sync.suspend",
            "remote.deleteAll:user-1",
            "auth.delete",
            "sync.forget:user-1",
            "widget.publish"
        ])
        #expect(fixture.expenses.fetchAll().isEmpty)
        #expect(fixture.categories.fetchAll().count == CoreDataCategoryRepository.defaults.count)
        #expect(fixture.auth.currentUserID == nil)
    }

    @Test("A wrong password stops everything before anything is deleted")
    func wrongPassword() async throws {
        let fixture = try DeletionFixture()
        fixture.auth.reauthError = AuthError.wrongCredentials

        await #expect(throws: AuthError.self) {
            try await fixture.service.deleteEverything(password: "wrong")
        }

        #expect(fixture.log.events == ["auth.reauth"])
        #expect(fixture.expenses.fetchAll().count == 1)
        #expect(fixture.auth.currentUserID == "user-1")
    }

    @Test("If the cloud delete fails the account and local data are kept and sync resumes")
    func cloudFailure() async throws {
        let fixture = try DeletionFixture()
        fixture.remote.deleteError = TestError()

        await #expect(throws: TestError.self) {
            try await fixture.service.deleteEverything(password: "Password1")
        }

        #expect(fixture.log.events == [
            "auth.reauth",
            "sync.suspend",
            "remote.deleteAll:user-1",
            "sync.resume"
        ])
        #expect(fixture.expenses.fetchAll().count == 1)
        #expect(fixture.auth.currentUserID == "user-1")
    }

    @Test("Offline deletion is refused so the cloud copy is not left behind")
    func offline() async throws {
        let fixture = try DeletionFixture(online: false)

        await #expect(throws: AccountDeletionError.offline) {
            try await fixture.service.deleteEverything(password: "Password1")
        }

        #expect(fixture.log.events.isEmpty)
        #expect(fixture.expenses.fetchAll().count == 1)
    }

    @Test("Nothing happens when nobody is signed in")
    func signedOut() async throws {
        let fixture = try DeletionFixture(signedIn: false)

        await #expect(throws: AccountDeletionError.notSignedIn) {
            try await fixture.service.deleteEverything(password: "Password1")
        }

        #expect(fixture.log.events.isEmpty)
    }

    @Test("Without cloud sync only the account and the phone are cleared, even offline")
    func withoutCloud() async throws {
        let fixture = try DeletionFixture(online: false, hasRemote: false)

        try await fixture.service.deleteEverything(password: "Password1")

        #expect(fixture.log.events == [
            "auth.reauth",
            "sync.suspend",
            "auth.delete",
            "sync.forget:user-1",
            "widget.publish"
        ])
        #expect(fixture.expenses.fetchAll().isEmpty)
    }
}

@MainActor
struct DeleteAccountViewModelTests {
    @MainActor
    final class StubService: AccountDeleting {
        var error: Error?
        var receivedPassword: String?

        func deleteEverything(password: String) async throws {
            receivedPassword = password
            if let error { throw error }
        }
    }

    @Test("Deleting needs a password")
    func needsPassword() async {
        let service = StubService()
        let viewModel = DeleteAccountViewModel(service: service)

        #expect(!viewModel.canSubmit)
        #expect(await viewModel.delete() == false)
        #expect(service.receivedPassword == nil)
    }

    @Test("A successful deletion clears the password")
    func success() async {
        let service = StubService()
        let viewModel = DeleteAccountViewModel(service: service)
        viewModel.password = "Password1"

        let deleted = await viewModel.delete()

        #expect(deleted)
        #expect(service.receivedPassword == "Password1")
        #expect(viewModel.password.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("A failure shows a message and keeps the password for another try")
    func failure() async {
        let service = StubService()
        service.error = AuthError.wrongCredentials
        let viewModel = DeleteAccountViewModel(service: service)
        viewModel.password = "nope"

        let deleted = await viewModel.delete()

        #expect(!deleted)
        #expect(viewModel.errorMessage == AuthError.wrongCredentials.errorDescription)
        #expect(viewModel.password == "nope")
        #expect(!viewModel.isWorking)
    }
}
