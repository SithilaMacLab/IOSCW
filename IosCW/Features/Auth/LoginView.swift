import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: AuthViewModel
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Password", text: $password)
                    .textContentType(.password)
            }

            Section {
                AuthMessageView(session: session)
            }

            Section {
                AuthSubmitButton(title: "Sign in",
                                 isWorking: session.isWorking,
                                 isEnabled: !email.isEmpty && !password.isEmpty) {
                    Task { await session.signIn(email: email, password: password) }
                }

                NavigationLink("Forgot password?") {
                    ForgotPasswordView(initialEmail: email)
                }
                .frame(minHeight: 44)
            }
        }
        .navigationTitle("Sign in")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { session.clearMessages() }
    }
}

#Preview {
    NavigationStack {
        LoginView()
    }
    .environmentObject(AuthViewModel(service: DevAuthService()))
}
