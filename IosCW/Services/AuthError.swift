import Foundation

enum AuthError: LocalizedError {
    case invalidEmail
    case weakPassword
    case emailAlreadyInUse
    case wrongCredentials
    case network
    case requiresRecentLogin
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail: "That email address doesn't look right."
        case .weakPassword: "Choose a stronger password: at least 8 characters with a letter and a number."
        case .emailAlreadyInUse: "An account with that email already exists. Try signing in."
        case .wrongCredentials: "The email or password is incorrect."
        case .network: "No connection. Check your internet and try again."
        case .requiresRecentLogin: "For your safety, sign out, sign in again and then retry."
        case .unknown(let message): message
        }
    }
}
