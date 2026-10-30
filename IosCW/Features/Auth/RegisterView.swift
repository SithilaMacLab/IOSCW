import SwiftUI

struct RegisterView: View {
    enum Field: Hashable {
        case email
        case password
        case confirm
    }

    @EnvironmentObject private var session: AuthViewModel
    let actions: AuthActions
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @FocusState private var focus: Field?

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty
    }

    private var hasLength: Bool { password.count >= 8 }

    private var hasLetterAndNumber: Bool {
        password.contains(where: \.isLetter) && password.contains(where: \.isNumber)
    }

    private var matches: Bool { !confirmPassword.isEmpty && password == confirmPassword }

    var body: some View {
        AuthScreen(style: .register,
                   title: "Create your account",
                   subtitle: "It takes a few seconds. Your data stays private to you.") {
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
                                  contentType: .newPassword,
                                  submitLabel: .next,
                                  focus: $focus,
                                  field: .password)

                AuthPasswordField(title: "Confirm password",
                                  text: $confirmPassword,
                                  contentType: .newPassword,
                                  submitLabel: .go,
                                  hasError: !confirmPassword.isEmpty && !matches,
                                  focus: $focus,
                                  field: .confirm)

                VStack(alignment: .leading, spacing: 6) {
                    RequirementRow(met: hasLength, text: "At least 8 characters")
                    RequirementRow(met: hasLetterAndNumber, text: "A letter and a number")
                    RequirementRow(met: matches, text: "Both passwords match")
                }
                .padding(.horizontal, 4)

                AuthMessageView(session: session)

                AuthPrimaryButton(title: "Create account",
                                  isWorking: session.isWorking,
                                  isEnabled: canSubmit) {
                    submit()
                }

                AuthSwitchRow(question: "Already have an account?", actionTitle: "Sign in") {
                    actions.replace(.login)
                }
            }
        }
        .onSubmit {
            switch focus {
            case .email:
                focus = .password
            case .password:
                focus = .confirm
            default:
                if canSubmit { submit() }
            }
        }
        .onAppear { session.clearMessages() }
    }

    private func submit() {
        focus = nil
        Task {
            await session.register(email: email,
                                   password: password,
                                   confirmPassword: confirmPassword)
        }
    }
}

#Preview {
    NavigationStack {
        RegisterView(actions: AuthActions())
    }
    .environmentObject(AuthViewModel(service: DevAuthService()))
}
