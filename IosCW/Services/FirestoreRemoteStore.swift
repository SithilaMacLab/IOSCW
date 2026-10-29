#if canImport(FirebaseFirestore)
import FirebaseFirestore
import Foundation

final class FirestoreRemoteStore: RemoteStoreProtocol {
    private let database: Firestore

    init() {
        let database = Firestore.firestore()
        let settings = database.settings
        settings.cacheSettings = MemoryCacheSettings()
        database.settings = settings
        self.database = database
    }

    func push(_ records: [SyncRecord], userID: String) async throws {
        for chunk in records.chunked(into: 400) {
            let batch = database.batch()
            for record in chunk {
                batch.setData(record.payload, forDocument: document(for: record, userID: userID))
            }
            try await Timeout.run(seconds: 30) {
                try await batch.commit()
            }
        }
    }

    func fetch(_ kind: SyncKind, since: Date?, userID: String) async throws -> [SyncRecord] {
        var query: Query = database.collection("users").document(userID).collection(kind.rawValue)
        if let since {
            query = query.whereField("lastEdited", isGreaterThanOrEqualTo: Timestamp(date: since))
        }
        let finalQuery = query

        let snapshot = try await Timeout.run(seconds: 30) {
            try await finalQuery.getDocuments(source: .server)
        }

        return snapshot.documents.compactMap { document in
            SyncRecord(kind: kind, documentID: document.documentID, data: Self.convertTimestamps(document.data()))
        }
    }

    func deleteAll(userID: String) async throws {
        let user = database.collection("users").document(userID)

        for kind in SyncKind.allCases {
            let collection = user.collection(kind.rawValue)
            for _ in 0..<500 {
                let snapshot = try await Timeout.run(seconds: 30) {
                    try await collection.limit(to: 400).getDocuments(source: .server)
                }
                guard !snapshot.documents.isEmpty else { break }

                let batch = database.batch()
                for document in snapshot.documents {
                    batch.deleteDocument(document.reference)
                }
                try await Timeout.run(seconds: 30) {
                    try await batch.commit()
                }
            }
        }

        try await Timeout.run(seconds: 30) {
            try await user.delete()
        }
    }

    private func document(for record: SyncRecord, userID: String) -> DocumentReference {
        database.collection("users").document(userID)
            .collection(record.kind.rawValue).document(record.id.uuidString)
    }

    private static func convertTimestamps(_ data: [String: Any]) -> [String: Any] {
        data.mapValues { value in
            if let timestamp = value as? Timestamp {
                return timestamp.dateValue()
            }
            return value
        }
    }
}
#endif
