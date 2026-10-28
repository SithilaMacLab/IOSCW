import SwiftUI

struct SettingsView: View {
    let container: AppContainer
    @EnvironmentObject private var session: AuthViewModel
    @EnvironmentObject private var lock: AppLockViewModel
    @EnvironmentObject private var sync: SyncEngine
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

                Section {
                    LabeledContent("Status", value: sync.statusText)

                    if sync.pendingCount > 0 {
                        LabeledContent("Waiting to upload", value: "\(sync.pendingCount)")
                    }

                    if let last = sync.lastSyncedAt {
                        LabeledContent("Last synced") {
                            Text("\(last, style: .relative) ago")
                        }
                    }

                    if case .failed(let message) = sync.status {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Button {
                        sync.syncNow()
                    } label: {
                        Label("Sync now", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(!sync.canSync)
                } header: {
                    Text("Cloud sync")
                } footer: {
                    if case .notConfigured = sync.status {
                        Text("Add the Firebase Firestore package to turn on cloud sync. Until then everything is saved on this phone only.")
                    } else {
                        Text("Changes save on this phone first and upload automatically when you're online.")
                    }
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
    let container = AppContainer.preview(withSamples: false)
    return SettingsView(container: container)
        .environmentObject(AuthViewModel(service: DevAuthService()))
        .environmentObject(AppLockViewModel())
        .environmentObject(container.sync)
}
