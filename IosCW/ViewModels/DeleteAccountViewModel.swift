import Combine
import Foundation

final class DeleteAccountViewModel: ObservableObject {
    @Published var password = ""
    @Published var errorMessage: String?
    @Published var isConfirming = false
    @Published private(set) var isWorking = false

    private let service: AccountDeleting

    init(service: AccountDeleting) {
        self.service = service
    }

    var canSubmit: Bool { !password.isEmpty && !isWorking }

    func delete() async -> Bool {
        guard canSubmit else { return false }
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }

        do {
            try await service.deleteEverything(password: password)
            password = ""
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
