import SwiftUI

struct SettingsView: View {
    let container: AppContainer
    @EnvironmentObject private var session: AuthViewModel
    @EnvironmentObject private var lock: AppLockViewModel
    @State private var loadedSamples = false
    @State private var confirmingSignOut = false

    private var lockBinding: Binding<Bool> {
        Binding(get: { lock.isEnabled },
                set: { newValue in Task { await lock.setEnabled(newValue) } })
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if let email = session.userEmail {
                        LabeledContent("Signed in as", value: email)
                    }
                    Button("Sign out", role: .destructive) {
                        confirmingSignOut = true
                    }
                    .frame(minHeight: 44)
                }

                Section("Manage") {
                    NavigationLink {
                        CategoriesView(container: container)
                    } label: {
                        Label("Categories", systemImage: "square.grid.2x2")
                    }
                }

                Section {
                    Toggle(isOn: lockBinding) {
                        Label("Lock with \(lock.methodName)", systemImage: lock.symbolName)
                    }
                    .disabled(lock.isAuthenticating)

                    if let message = lock.errorMessage {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Security")
                } footer: {
                    Text("Locks the app when you open it and when you return to it. Your device passcode works as a fallback.")
                }

                Section("Data") {
                    Text("Export CSV")
                    Text("Delete account and data")
                }

                #if DEBUG
                Section {
                    Button {
                        SampleData.populate(container)
                        loadedSamples = true
                    } label: {
                        Label("Load sample data", systemImage: "wand.and.stars")
                    }
                    .disabled(loadedSamples)
                } header: {
                    Text("Developer")
                } footer: {
                    Text("Adds 4 months of fake transactions and some budgets so you can see the charts. Debug builds only.")
                }
                #endif
            }
            .navigationTitle("Settings")
            .confirmationDialog("Sign out of \(AppConstants.appName)?",
                                isPresented: $confirmingSignOut,
                                titleVisibility: .visible) {
                Button("Sign out", role: .destructive) { session.signOut() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

#Preview {
    SettingsView(container: .preview(withSamples: false))
        .environmentObject(AuthViewModel(service: DevAuthService()))
        .environmentObject(AppLockViewModel())
}
