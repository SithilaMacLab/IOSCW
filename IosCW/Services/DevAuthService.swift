import Foundation

final class DevAuthService: AuthServiceProtocol {
    private let defaults: UserDefaults
    private let key = "devAuthEmail"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isSignedIn: Bool { currentUserEmail != nil }

    var currentUserEmail: String? { defaults.string(forKey: key) }

    var currentUserID: String? { currentUserEmail }

    func register(email: String, password: String) async throws {
        try validate(email: email, password: password)
        defaults.set(AuthValidator.normalized(email), forKey: key)
    }

    func signIn(email: String, password: String) async throws {
        guard AuthValidator.isValidEmail(email), !password.isEmpty else { throw AuthError.wrongCredentials }
        defaults.set(AuthValidator.normalized(email), forKey: key)
    }

    func signOut() throws {
        defaults.removeObject(forKey: key)
    }

    func resetPassword(email: String) async throws {
        guard AuthValidator.isValidEmail(email) else { throw AuthError.invalidEmail }
    }

    private func validate(email: String, password: String) throws {
        guard AuthValidator.isValidEmail(email) else { throw AuthError.invalidEmail }
        guard AuthValidator.passwordProblem(password) == nil else { throw AuthError.weakPassword }
    }
}
