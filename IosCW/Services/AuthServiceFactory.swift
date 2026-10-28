import Foundation

enum AuthServiceFactory {
    static func makeLive() -> AuthServiceProtocol {
        #if canImport(FirebaseAuth)
        if FirebaseBootstrap.configureIfPossible() {
            return FirebaseAuthService()
        }
        #endif
        return DevAuthService()
    }
}
