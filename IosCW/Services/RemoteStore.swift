import Foundation

protocol RemoteStoreProtocol {
    func push(_ records: [SyncRecord], userID: String) async throws
    func fetch(_ kind: SyncKind, since: Date?, userID: String) async throws -> [SyncRecord]
    func deleteAll(userID: String) async throws
}

enum RemoteStoreFactory {
    static func makeLive() -> RemoteStoreProtocol? {
        #if canImport(FirebaseFirestore)
        if FirebaseBootstrap.configureIfPossible() {
            return FirestoreRemoteStore()
        }
        #endif
        return nil
    }
}
