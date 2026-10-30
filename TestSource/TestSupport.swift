import Foundation
@testable import IosCW

struct TestError: Error {}

enum TestClock {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}

func isolatedDefaults() -> UserDefaults {
    let name = "pocketlens.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

@MainActor
func waitUntil(timeout: Double = 5, _ condition: @MainActor () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(50))
    }
    return condition()
}

@MainActor
func forecastEntry(_ date: Date,
                   _ amount: Double,
                   type: TransactionType = .expense,
                   category: String = "food") -> ForecastEntry {
    ForecastEntry(date: date,
                  amount: amount,
                  type: type,
                  categoryID: category,
                  categoryName: category.capitalized,
                  colorHex: "#FF9500",
                  iconName: "fork.knife")
}

func isClose(_ first: Double, _ second: Double, tolerance: Double = 0.001) -> Bool {
    abs(first - second) < tolerance
}

@MainActor
final class EventLog {
    var events: [String] = []
}

@MainActor
final class FakeRemote: RemoteStoreProtocol {
    var stored: [SyncKind: [UUID: SyncRecord]] = [:]
    var pushed: [SyncRecord] = []
    var fetchCount = 0
    var deleteError: Error?
    var log: EventLog?

    func put(_ record: SyncRecord) {
        stored[record.kind, default: [:]][record.id] = record
    }

    func push(_ records: [SyncRecord], userID: String) async throws {
        pushed.append(contentsOf: records)
        for record in records {
            put(record)
        }
    }

    func fetch(_ kind: SyncKind, since: Date?, userID: String) async throws -> [SyncRecord] {
        fetchCount += 1
        let all = Array((stored[kind] ?? [:]).values)
        guard let since else { return all }
        return all.filter { $0.lastEdited >= since }
    }

    func deleteAll(userID: String) async throws {
        log?.events.append("remote.deleteAll:\(userID)")
        if let deleteError { throw deleteError }
        stored = [:]
    }
}

@MainActor
final class FakeAuth: AuthServiceProtocol {
    var userID: String?
    var reauthError: Error?
    let log: EventLog

    init(userID: String? = "user-1", log: EventLog? = nil) {
        self.userID = userID
        self.log = log ?? EventLog()
    }

    var isSignedIn: Bool { userID != nil }
    var currentUserEmail: String? { userID.map { "\($0)@example.com" } }
    var currentUserID: String? { userID }

    func register(email: String, password: String) async throws {}
    func signIn(email: String, password: String) async throws {}
    func signOut() throws { userID = nil }
    func resetPassword(email: String) async throws {}

    func reauthenticate(password: String) async throws {
        log.events.append("auth.reauth")
        if let reauthError { throw reauthError }
    }

    func deleteAccount() async throws {
        log.events.append("auth.delete")
        userID = nil
    }
}

@MainActor
final class FakeSync: SyncControlling {
    let log: EventLog

    init(log: EventLog) {
        self.log = log
    }

    func suspendForAccountDeletion() async { log.events.append("sync.suspend") }
    func resumeAfterFailedDeletion() { log.events.append("sync.resume") }
    func forgetAccount(userID: String) { log.events.append("sync.forget:\(userID)") }
}

@MainActor
final class FakeWidget: WidgetPublishing {
    let log: EventLog

    init(log: EventLog) {
        self.log = log
    }

    func publish() { log.events.append("widget.publish") }
}

@MainActor
func monthlyEntries(_ amounts: [Double],
                    now: Date,
                    category: String = "food",
                    type: TransactionType = .expense) -> [ForecastEntry] {
    let calendar = TestClock.calendar
    let currentStart = calendar.dateInterval(of: .month, for: now)!.start
    return amounts.enumerated().map { index, amount in
        let offset = amounts.count - index
        let monthStart = calendar.date(byAdding: .month, value: -offset, to: currentStart)!
        let date = calendar.date(byAdding: .day, value: 9, to: monthStart)!
        return forecastEntry(date, amount, type: type, category: category)
    }
}

@MainActor
final class ClockBox {
    var date: Date

    init(_ date: Date) {
        self.date = date
    }
}
