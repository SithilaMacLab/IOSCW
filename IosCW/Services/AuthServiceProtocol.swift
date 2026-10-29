import Foundation

protocol AuthServiceProtocol {
    var isSignedIn: Bool { get }
    var currentUserEmail: String? { get }
    var currentUserID: String? { get }
    func register(email: String, password: String) async throws
    func signIn(email: String, password: String) async throws
    func signOut() throws
    func resetPassword(email: String) async throws
    func reauthenticate(password: String) async throws
    func deleteAccount() async throws
}
