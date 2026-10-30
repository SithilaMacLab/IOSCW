import SwiftUI

struct LoginView: View {
    enum Field: Hashable {
        case email
        case password
    }

    @EnvironmentObject private var session: AuthViewModel
    let actions: AuthActions
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focus: Field?

    private var canSubmit: Bool { !email.isEmpty && !password.isEmpty }

    var body: some View {
        AuthScreen(style: .login,
                   title: "Welcome back",
                   subtitle: "Sign in to see your spending and sync your data.") {
            VStack(spacing: 14) {
                AuthTextField(title: "Email",
                              text: $email,
                              systemImage: "envelope.fill",
                              contentType: .emailAddress,
                              keyboard: .emailAddress,
                              submitLabel: .next,
                              focus: $focus,
                              field: .email)

                AuthPasswordField(title: "Password",
                                  text: $password,
                                  contentType: .password,
                                  submitLabel: .go,
                                  focus: $focus,
                                  field: .password)

                HStack {
                    Spacer()
                    Button("Forgot password?") {
                        actions.go(.forgot(email: email))
                    }
                    .font(.subheadline)
                    .frame(minHeight: 44)
                }

                AuthMessageView(session: session)

                AuthPrimaryButton(title: "Sign in",
                                  isWorking: session.isWorking,
                                  isEnabled: canSubmit) {
                    submit()
                }

                AuthSwitchRow(question: "New to \(AppConstants.appName)?", actionTitle: "Create account") {
                    actions.replace(.register)
                }
            }
        }
        .onSubmit {
            if focus == .email {
                focus = .password
            } else if canSubmit {
                submit()
            }
        }
        .onAppear { session.clearMessages() }
    }

    private func submit() {
        focus = nil
        Task { await session.signIn(email: email, password: password) }
    }
}

#Preview {
    NavigationStack {
        LoginView(actions: AuthActions())
    }
    .environmentObject(AuthViewModel(service: DevAuthService()))
}
