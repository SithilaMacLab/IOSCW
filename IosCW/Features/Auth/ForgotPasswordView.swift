import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject private var session: AuthViewModel
    @State private var email: String

    init(initialEmail: String = "") {
        _email = State(initialValue: initialEmail)
    }

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } footer: {
                Text("We'll email you a link to choose a new password.")
            }

            Section {
                AuthMessageView(session: session)
            }

            Section {
                AuthSubmitButton(title: "Send reset link",
                                 isWorking: session.isWorking,
                                 isEnabled: !email.isEmpty) {
                    Task { await session.sendPasswordReset(email: email) }
                }
            }
        }
        .navigationTitle("Reset password")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { session.clearMessages() }
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView()
    }
    .environmentObject(AuthViewModel(service: DevAuthService()))
}
