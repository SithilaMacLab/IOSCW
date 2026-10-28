import Foundation

enum SyncKind: String, CaseIterable {
    case categories
    case budgets
    case expenses

    var entityName: String {
        switch self {
        case .categories: "ExpenseCategory"
        case .budgets: "Budget"
        case .expenses: "Expense"
        }
    }
}

struct SyncRecord {
    let kind: SyncKind
    let id: UUID
    let lastEdited: Date
    let isDeleted: Bool
    let fields: [String: Any]

    init(kind: SyncKind, id: UUID, lastEdited: Date, isDeleted: Bool, fields: [String: Any]) {
        self.kind = kind
        self.id = id
        self.lastEdited = lastEdited
        self.isDeleted = isDeleted
        self.fields = fields
    }

    init?(kind: SyncKind, documentID: String, data: [String: Any]) {
        guard let id = UUID(uuidString: documentID),
              let lastEdited = data["lastEdited"] as? Date else {
            return nil
        }
        var fields = data
        fields.removeValue(forKey: "lastEdited")
        fields.removeValue(forKey: "isDeleted")
        self.init(kind: kind,
                  id: id,
                  lastEdited: lastEdited,
                  isDeleted: (data["isDeleted"] as? Bool) ?? false,
                  fields: fields)
    }

    var payload: [String: Any] {
        var data = fields
        data["lastEdited"] = lastEdited
        data["isDeleted"] = isDeleted
        return data
    }

    func string(_ key: String) -> String? {
        fields[key] as? String
    }

    func bool(_ key: String) -> Bool? {
        fields[key] as? Bool
    }

    func date(_ key: String) -> Date? {
        fields[key] as? Date
    }

    func double(_ key: String) -> Double? {
        if let value = fields[key] as? Double { return value }
        if let value = fields[key] as? Int { return Double(value) }
        if let value = fields[key] as? Int64 { return Double(value) }
        return nil
    }
}

enum SyncError: LocalizedError {
    case timeout

    var errorDescription: String? {
        switch self {
        case .timeout: "The server took too long to answer."
        }
    }
}
