import SwiftUI

struct ForgotPasswordView: View {
    enum Field: Hashable {
        case email
    }

    @EnvironmentObject private var session: AuthViewModel
    @State private var email: String
    @FocusState private var focus: Field?

    init(initialEmail: String = "") {
        _email = State(initialValue: initialEmail)
    }

    var body: some View {
        AuthScreen(style: .reset,
                   title: "Reset your password",
                   subtitle: "Enter your email and we will send you a link to choose a new password.") {
            VStack(spacing: 14) {
                AuthTextField(title: "Email",
                              text: $email,
                              systemImage: "envelope.fill",
                              contentType: .emailAddress,
                              keyboard: .emailAddress,
                              submitLabel: .send,
                              focus: $focus,
                              field: .email)

                AuthMessageView(session: session)

                AuthPrimaryButton(title: "Send reset link",
                                  isWorking: session.isWorking,
                                  isEnabled: !email.isEmpty) {
                    send()
                }
            }
        }
        .onSubmit {
            if !email.isEmpty { send() }
        }
        .onAppear { session.clearMessages() }
    }

    private func send() {
        focus = nil
        Task { await session.sendPasswordReset(email: email) }
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView()
    }
    .environmentObject(AuthViewModel(service: DevAuthService()))
}
