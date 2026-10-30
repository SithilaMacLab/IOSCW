import Combine
import Foundation

final class AuthViewModel: ObservableObject {
    @Published private(set) var isSignedIn: Bool
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let service: AuthServiceProtocol
    private let beforeSignIn: ((String) -> Void)?
    private let afterSignOut: (() -> Void)?

    init(service: AuthServiceProtocol,
         beforeSignIn: ((String) -> Void)? = nil,
         afterSignOut: (() -> Void)? = nil) {
        self.service = service
        self.beforeSignIn = beforeSignIn
        self.afterSignOut = afterSignOut
        isSignedIn = service.isSignedIn
    }

    var userEmail: String? { service.currentUserEmail }

    func refreshSession() {
        isSignedIn = service.isSignedIn
    }

    func clearMessages() {
        errorMessage = nil
        infoMessage = nil
    }

    func signIn(email: String, password: String) async {
        clearMessages()
        guard AuthValidator.isValidEmail(email) else {
            errorMessage = AuthError.invalidEmail.errorDescription
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Enter your password."
            return
        }
        let cleaned = AuthValidator.normalized(email)
        if await perform({ try await self.service.signIn(email: cleaned, password: password) }) {
            completeSignIn()
        }
    }

    func register(email: String, password: String, confirmPassword: String) async {
        clearMessages()
        if let problem = AuthValidator.registrationProblem(email: email,
                                                           password: password,
                                                           confirmPassword: confirmPassword) {
            errorMessage = problem
            return
        }
        let cleaned = AuthValidator.normalized(email)
        if await perform({ try await self.service.register(email: cleaned, password: password) }) {
            completeSignIn()
        }
    }

    func sendPasswordReset(email: String) async {
        clearMessages()
        guard AuthValidator.isValidEmail(email) else {
            errorMessage = AuthError.invalidEmail.errorDescription
            return
        }
        let cleaned = AuthValidator.normalized(email)
        if await perform({ try await self.service.resetPassword(email: cleaned) }) {
            infoMessage = "If an account exists for \(cleaned), a reset link is on its way."
        }
    }

    func signOut() {
        clearMessages()
        do {
            try service.signOut()
            afterSignOut?()
            isSignedIn = service.isSignedIn
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func completeSignIn() {
        if let userID = service.currentUserID {
            beforeSignIn?(userID)
        }
        isSignedIn = service.isSignedIn
    }

    private func perform(_ work: () async throws -> Void) async -> Bool {
        isWorking = true
        defer { isWorking = false }
        do {
            try await work()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
