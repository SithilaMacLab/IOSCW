#if canImport(FirebaseAuth)
import FirebaseAuth
import Foundation

final class FirebaseAuthService: AuthServiceProtocol {
    var isSignedIn: Bool { Auth.auth().currentUser != nil }

    var currentUserEmail: String? { Auth.auth().currentUser?.email }

    var currentUserID: String? { Auth.auth().currentUser?.uid }

    func register(email: String, password: String) async throws {
        do {
            _ = try await Auth.auth().createUser(withEmail: email, password: password)
        } catch {
            throw Self.map(error)
        }
    }

    func signIn(email: String, password: String) async throws {
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            throw Self.map(error)
        }
    }

    func signOut() throws {
        do {
            try Auth.auth().signOut()
        } catch {
            throw Self.map(error)
        }
    }

    func resetPassword(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            throw Self.map(error)
        }
    }

    func reauthenticate(password: String) async throws {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            throw AuthError.wrongCredentials
        }
        do {
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            try await user.reauthenticate(with: credential)
        } catch {
            throw Self.map(error)
        }
    }

    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { return }
        do {
            try await user.delete()
        } catch {
            throw Self.map(error)
        }
    }

    private static func map(_ error: Error) -> AuthError {
        let nsError = error as NSError
        guard let code = AuthErrorCode(rawValue: nsError.code) else {
            return .unknown(error.localizedDescription)
        }
        switch code {
        case .invalidEmail: return .invalidEmail
        case .weakPassword: return .weakPassword
        case .emailAlreadyInUse: return .emailAlreadyInUse
        case .wrongPassword, .userNotFound, .invalidCredential: return .wrongCredentials
        case .networkError: return .network
        case .requiresRecentLogin: return .requiresRecentLogin
        default: return .unknown(error.localizedDescription)
        }
    }
}
#endif
