import Combine
import Foundation

final class ExportViewModel: ObservableObject {
    @Published private(set) var fileURL: URL?
    @Published var errorMessage: String?

    private let repository: ExpenseRepositoryProtocol
    private var previousFile: URL?

    init(expenses: ExpenseRepositoryProtocol) {
        repository = expenses
    }

    var isSharing: Bool {
        get { fileURL != nil }
        set { if !newValue { fileURL = nil } }
    }

    func prepare() {
        let expenses = repository.fetchAll()
        guard !expenses.isEmpty else {
            errorMessage = "There are no transactions to export yet."
            return
        }

        let rows = expenses.sorted { $0.date < $1.date }.map { CSVRow($0) }
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data(CSVExporter.make(rows).utf8))

        if let previousFile {
            try? FileManager.default.removeItem(at: previousFile)
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(CSVExporter.fileName())
        do {
            try data.write(to: url, options: .atomic)
            previousFile = url
            fileURL = url
        } catch {
            errorMessage = "The file could not be created. Check that your phone has free space and try again."
        }
    }
}
