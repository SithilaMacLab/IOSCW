import Combine
import CoreData
import Foundation

enum SyncStatus: Equatable {
    case notConfigured
    case signedOut
    case idle
    case syncing
    case offline
    case failed(String)
    case synced(Date)
}

final class SyncEngine: ObservableObject {
    @Published private(set) var status: SyncStatus
    @Published private(set) var pendingCount = 0
    @Published private(set) var lastSyncedAt: Date?

    private let persistence: PersistenceController
    private let remote: RemoteStoreProtocol?
    private let auth: AuthServiceProtocol
    private let network: NetworkMonitor
    private let categories: CategoryRepositoryProtocol
    private let defaults: UserDefaults

    private var isSyncing = false
    private var isSuspended = false
    private var retryDelay: TimeInterval = 5
    private var debounceTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private let ownerKey = "syncOwnerUserID"
    private let lastSyncedKey = "syncLastSyncedAt"

    init(persistence: PersistenceController,
         remote: RemoteStoreProtocol?,
         auth: AuthServiceProtocol,
         network: NetworkMonitor,
         categories: CategoryRepositoryProtocol,
         defaults: UserDefaults = .standard) {
        self.persistence = persistence
        self.remote = remote
        self.auth = auth
        self.network = network
        self.categories = categories
        self.defaults = defaults

        status = remote == nil ? .notConfigured : .signedOut
        lastSyncedAt = defaults.object(forKey: lastSyncedKey) as? Date
        refreshPending()

        network.$isOnline
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] online in self?.networkChanged(online) }
            .store(in: &cancellables)

        observeDataChanges { [weak self] in self?.dataChanged() }
            .store(in: &cancellables)
    }

    var canSync: Bool {
        remote != nil && auth.currentUserID != nil && status != .syncing
    }

    var statusText: String {
        switch status {
        case .notConfigured: "Cloud sync is off"
        case .signedOut: "Not signed in"
        case .idle: "Ready"
        case .syncing: "Syncing…"
        case .offline: "Offline"
        case .failed: "Sync problem"
        case .synced: "Synced"
        }
    }

    func sessionChanged() {
        if startSession() {
            requestSync()
        }
    }

    func sessionChangedAndWait() async {
        if startSession() {
            await syncAndWait()
        }
    }

    func appBecameActive() {
        requestSync()
    }

    func syncNow() {
        retryDelay = 5
        requestSync()
    }

    func syncAndWait() async {
        guard remote != nil, auth.currentUserID != nil, !isSuspended else { return }
        guard network.isOnline else {
            status = .offline
            refreshPending()
            return
        }
        await runSync()
    }

    func suspendForAccountDeletion() async {
        isSuspended = true
        debounceTask?.cancel()
        retryTask?.cancel()
        while isSyncing {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    func resumeAfterFailedDeletion() {
        isSuspended = false
    }

    func forgetAccount(userID: String) {
        let prefix = "syncLastPull.\(userID)."
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
        defaults.removeObject(forKey: ownerKey)
        defaults.removeObject(forKey: lastSyncedKey)
        lastSyncedAt = nil
        isSuspended = false
        refreshPending()
        status = remote == nil ? .notConfigured : .signedOut
    }

    private func startSession() -> Bool {
        guard remote != nil else {
            status = .notConfigured
            return false
        }
        guard let userID = auth.currentUserID else {
            debounceTask?.cancel()
            retryTask?.cancel()
            status = .signedOut
            return false
        }
        prepareLocalData(for: userID)
        return true
    }

    private func requestSync() {
        Task { await syncAndWait() }
    }

    private func networkChanged(_ online: Bool) {
        guard remote != nil, auth.currentUserID != nil, !isSuspended else { return }
        if online {
            requestSync()
        } else {
            refreshPending()
            if !isSyncing {
                status = .offline
            }
        }
    }

    private func dataChanged() {
        refreshPending()
        guard !isSyncing, !isSuspended, remote != nil, auth.currentUserID != nil, pendingCount > 0 else { return }
        guard network.isOnline else {
            status = .offline
            return
        }
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await runSync()
        }
    }

    private func runSync() async {
        guard !isSyncing, !isSuspended, let remote, let userID = auth.currentUserID, network.isOnline else { return }
        isSyncing = true
        retryTask?.cancel()
        status = .syncing
        defer { isSyncing = false }

        do {
            for _ in 0..<3 {
                try await push(to: remote, userID: userID)
                try await pull(from: remote, userID: userID)
                refreshPending()
                if pendingCount == 0 { break }
            }

            guard auth.currentUserID == userID else { return }
            let now = Date()
            lastSyncedAt = now
            defaults.set(now, forKey: lastSyncedKey)
            retryDelay = 5
            status = .synced(now)
        } catch {
            refreshPending()
            guard auth.currentUserID == userID else { return }
            status = network.isOnline ? .failed(error.localizedDescription) : .offline
            scheduleRetry()
        }
    }

    private func scheduleRetry() {
        retryTask?.cancel()
        let delay = retryDelay
        retryDelay = min(retryDelay * 3, 300)
        retryTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await runSync()
        }
    }

    private func push(to remote: RemoteStoreProtocol, userID: String) async throws {
        let context = persistence.viewContext

        for kind in SyncKind.allCases {
            let snapshots = pendingObjects(of: kind).compactMap { object -> (object: any SyncTracked, edited: Date, record: SyncRecord)? in
                guard let record = SyncMapper.record(for: object) else { return nil }
                return (object, object.lastEdited, record)
            }

            for chunk in snapshots.chunked(into: 400) {
                try await remote.push(chunk.map { $0.record }, userID: userID)

                for item in chunk {
                    let object = item.object
                    guard !object.isDeleted, object.lastEdited == item.edited else { continue }
                    if object.isSoftDeleted {
                        context.delete(object)
                    } else {
                        object.syncState = .synced
                    }
                }
                try persistence.save(notify: false)
            }
        }
    }

    private func pull(from remote: RemoteStoreProtocol, userID: String) async throws {
        var newest: [SyncKind: Date] = [:]

        for kind in SyncKind.allCases {
            let records = try await remote.fetch(kind, since: lastPull(kind, userID: userID), userID: userID)
            guard !records.isEmpty else { continue }
            merge(records)
            if let latest = records.map(\.lastEdited).max() {
                newest[kind] = latest
            }
        }

        try persistence.save()
        for (kind, date) in newest {
            setLastPull(date, kind: kind, userID: userID)
        }
    }

    private func merge(_ records: [SyncRecord]) {
        let context = persistence.viewContext

        for record in records {
            if let local = existingObject(for: record) {
                guard let tracked = local as? any SyncTracked else { continue }
                if tracked.lastEdited >= record.lastEdited { continue }
                if record.isDeleted {
                    context.delete(local)
                } else {
                    SyncMapper.apply(record, to: local, in: context)
                }
            } else if !record.isDeleted {
                let object = NSEntityDescription.insertNewObject(forEntityName: record.kind.entityName, into: context)
                SyncMapper.apply(record, to: object, in: context)
            }
        }
    }

    private func existingObject(for record: SyncRecord) -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: record.kind.entityName)
        request.predicate = NSPredicate(format: "id == %@", record.id as CVarArg)
        request.fetchLimit = 1
        return (try? persistence.viewContext.fetch(request))?.first
    }

    private func pendingObjects(of kind: SyncKind) -> [any SyncTracked] {
        let request = NSFetchRequest<NSManagedObject>(entityName: kind.entityName)
        request.predicate = NSPredicate(format: "syncStateRaw == %@", SyncState.pending.rawValue)
        let objects = (try? persistence.viewContext.fetch(request)) ?? []
        return objects.compactMap { $0 as? any SyncTracked }
    }

    private func refreshPending() {
        let context = persistence.viewContext
        pendingCount = SyncKind.allCases.reduce(0) { total, kind in
            let request = NSFetchRequest<NSManagedObject>(entityName: kind.entityName)
            request.predicate = NSPredicate(format: "syncStateRaw == %@", SyncState.pending.rawValue)
            return total + ((try? context.count(for: request)) ?? 0)
        }
    }

    private func prepareLocalData(for userID: String) {
        let owner = defaults.string(forKey: ownerKey)
        guard owner != userID else { return }

        if owner != nil {
            try? persistence.wipeAll()
            try? categories.seedDefaultsIfNeeded()
            lastSyncedAt = nil
            defaults.removeObject(forKey: lastSyncedKey)
        }
        defaults.set(userID, forKey: ownerKey)
        refreshPending()
    }

    private func lastPull(_ kind: SyncKind, userID: String) -> Date? {
        defaults.object(forKey: pullKey(kind, userID: userID)) as? Date
    }

    private func setLastPull(_ date: Date, kind: SyncKind, userID: String) {
        defaults.set(date, forKey: pullKey(kind, userID: userID))
    }

    private func pullKey(_ kind: SyncKind, userID: String) -> String {
        "syncLastPull.\(userID).\(kind.rawValue)"
    }
}
