import Foundation

protocol AuthServiceProtocol {
    var isSignedIn: Bool { get }
    func register(email: String, password: String) async throws
    func signIn(email: String, password: String) async throws
    func signOut() throws
    func resetPassword(email: String) async throws
}
