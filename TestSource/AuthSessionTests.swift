import Foundation
import Testing
@testable import IosCW

@MainActor
final class SessionRecorder {
    var claimed: [String] = []
    var signOuts = 0
}

@MainActor
struct AuthSessionTests {
    private func makeViewModel(_ recorder: SessionRecorder) -> AuthViewModel {
        AuthViewModel(service: DevAuthService(defaults: isolatedDefaults()),
                      beforeSignIn: { recorder.claimed.append($0) },
                      afterSignOut: { recorder.signOuts += 1 })
    }

    @Test("The phone's data is claimed for the user before the app opens")
    func claimsBeforeOpening() async {
        let recorder = SessionRecorder()
        let viewModel = makeViewModel(recorder)

        await viewModel.signIn(email: "Alice@Example.com", password: "Password1")

        #expect(recorder.claimed == ["alice@example.com"])
        #expect(viewModel.isSignedIn)
    }

    @Test("Registering also claims the phone's data")
    func registerClaims() async {
        let recorder = SessionRecorder()
        let viewModel = makeViewModel(recorder)

        await viewModel.register(email: "bob@example.com", password: "Password1", confirmPassword: "Password1")

        #expect(recorder.claimed == ["bob@example.com"])
        #expect(viewModel.isSignedIn)
    }

    @Test("A failed sign in claims nothing and stays signed out")
    func failedSignIn() async {
        let recorder = SessionRecorder()
        let viewModel = makeViewModel(recorder)

        await viewModel.signIn(email: "not-an-email", password: "x")

        #expect(recorder.claimed.isEmpty)
        #expect(!viewModel.isSignedIn)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("Signing out clears the phone before the screen changes")
    func signOutClears() async {
        let recorder = SessionRecorder()
        let viewModel = makeViewModel(recorder)
        await viewModel.signIn(email: "alice@example.com", password: "Password1")

        viewModel.signOut()

        #expect(recorder.signOuts == 1)
        #expect(!viewModel.isSignedIn)
    }
}
