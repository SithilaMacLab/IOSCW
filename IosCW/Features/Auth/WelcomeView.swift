import SwiftUI

struct WelcomeView: View {
    @State private var path: [AuthRoute] = []

    private var actions: AuthActions {
        AuthActions(
            go: { route in path.append(route) },
            replace: { route in
                if path.isEmpty {
                    path.append(route)
                } else {
                    path[path.count - 1] = route
                }
            })
    }

    var body: some View {
        NavigationStack(path: $path) {
            AuthScreen(style: .welcome,
                       title: AppConstants.appName,
                       subtitle: "Scan receipts, track spending and see where your money goes.",
                       heroSize: 240) {
                VStack(spacing: 16) {
                    FeatureRow(symbol: "doc.text.viewfinder", color: .blue,
                               title: "Scan a receipt",
                               detail: "The amount, date and shop are read on your phone.")
                    FeatureRow(symbol: "chart.pie.fill", color: .orange,
                               title: "See where it goes",
                               detail: "Budgets, charts, a map and a month-end forecast.")
                    FeatureRow(symbol: "icloud.slash.fill", color: .green,
                               title: "Works offline",
                               detail: "Everything saves first and syncs when you are back online.")
                }
                .padding(.vertical, 4)

                VStack(spacing: 8) {
                    AuthPrimaryButton(title: "Create account", isWorking: false, isEnabled: true) {
                        path.append(.register)
                    }
                    AuthSwitchRow(question: "Already have an account?", actionTitle: "Sign in") {
                        path.append(.login)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .login:
                    LoginView(actions: actions)
                case .register:
                    RegisterView(actions: actions)
                case .forgot(let email):
                    ForgotPasswordView(initialEmail: email)
                }
            }
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AuthViewModel(service: DevAuthService()))
}
