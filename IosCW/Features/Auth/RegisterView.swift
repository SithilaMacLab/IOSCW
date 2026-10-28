import SwiftUI

struct RegisterView: View {
    @EnvironmentObject private var session: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Password", text: $password)
                    .textContentType(.newPassword)

                SecureField("Confirm password", text: $confirmPassword)
                    .textContentType(.newPassword)
            } footer: {
                Text("At least 8 characters, with a letter and a number.")
            }

            Section {
                AuthMessageView(session: session)
            }

            Section {
                AuthSubmitButton(title: "Create account",
                                 isWorking: session.isWorking,
                                 isEnabled: canSubmit) {
                    Task {
                        await session.register(email: email,
                                               password: password,
                                               confirmPassword: confirmPassword)
                    }
                }
            }
        }
        .navigationTitle("Create account")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { session.clearMessages() }
    }
}

#Preview {
    NavigationStack {
        RegisterView()
    }
    .environmentObject(AuthViewModel(service: DevAuthService()))
}
