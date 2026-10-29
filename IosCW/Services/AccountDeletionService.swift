import Foundation

enum AccountDeletionError: LocalizedError, Equatable {
    case notSignedIn
    case offline
    case localCleanupFailed

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            "You are not signed in."
        case .offline:
            "Connect to the internet first, so your cloud copy can be deleted too."
        case .localCleanupFailed:
            "Your account was deleted, but some data could not be cleared from this phone. Delete the app to remove it."
        }
    }
}

protocol SyncControlling {
    func suspendForAccountDeletion() async
    func resumeAfterFailedDeletion()
    func forgetAccount(userID: String)
}

extension SyncEngine: SyncControlling {}

protocol AccountDeleting {
    func deleteEverything(password: String) async throws
}

final class AccountDeletionService: AccountDeleting {
    private let auth: AuthServiceProtocol
    private let remote: RemoteStoreProtocol?
    private let sync: SyncControlling
    private let persistence: PersistenceController
    private let categories: CategoryRepositoryProtocol
    private let widget: WidgetPublishing
    private let network: NetworkMonitor

    init(auth: AuthServiceProtocol,
         remote: RemoteStoreProtocol?,
         sync: SyncControlling,
         persistence: PersistenceController,
         categories: CategoryRepositoryProtocol,
         widget: WidgetPublishing,
         network: NetworkMonitor) {
        self.auth = auth
        self.remote = remote
        self.sync = sync
        self.persistence = persistence
        self.categories = categories
        self.widget = widget
        self.network = network
    }

    func deleteEverything(password: String) async throws {
        guard let userID = auth.currentUserID else { throw AccountDeletionError.notSignedIn }
        if remote != nil, !network.isOnline { throw AccountDeletionError.offline }

        try await auth.reauthenticate(password: password)
        await sync.suspendForAccountDeletion()

        do {
            if let remote {
                try await remote.deleteAll(userID: userID)
            }
            try await auth.deleteAccount()
        } catch {
            sync.resumeAfterFailedDeletion()
            throw error
        }

        sync.forgetAccount(userID: userID)

        do {
            try persistence.wipeAll()
            try categories.seedDefaultsIfNeeded()
        } catch {
            widget.publish()
            throw AccountDeletionError.localCleanupFailed
        }
        widget.publish()
    }
}
