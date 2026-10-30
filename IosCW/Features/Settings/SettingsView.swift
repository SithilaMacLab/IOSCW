import SwiftUI

struct SettingsView: View {
    let container: AppContainer
    @EnvironmentObject private var session: AuthViewModel
    @EnvironmentObject private var lock: AppLockViewModel
    @EnvironmentObject private var sync: SyncEngine
    @StateObject private var export: ExportViewModel
    @State private var loadedSamples = false
    @State private var confirmingSignOut = false
    @State private var showingDelete = false
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue

    init(container: AppContainer) {
        self.container = container
        _export = StateObject(wrappedValue: ExportViewModel(expenses: container.expenses))
    }

    private var hasUnsyncedChanges: Bool {
        container.sync.isCloudEnabled && sync.pendingCount > 0
    }

    private var signOutMessage: String {
        if hasUnsyncedChanges {
            return "\(sync.pendingCount) \(sync.pendingCount == 1 ? "change has" : "changes have") not been uploaded yet. Signing out clears this phone, so connect to the internet and sync first or they will be lost."
        }
        if container.sync.isCloudEnabled {
            return "Your data is safe in the cloud. It is removed from this phone when you sign out and comes back when you sign in again."
        }
        return "Cloud sync is off, so your data stays on this phone. Signing in as a different user will erase it."
    }

    private var exportErrorBinding: Binding<Bool> {
        Binding(get: { export.errorMessage != nil },
                set: { if !$0 { export.errorMessage = nil } })
    }

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
                    LabeledContent("Sign-in service",
                                   value: FirebaseDiagnosis.problem == nil ? "Firebase" : "This phone only")
                    Button("Sign out", role: .destructive) {
                        confirmingSignOut = true
                    }
                    .frame(minHeight: 44)
                }

                Section {
                    Picker("Appearance", selection: $appearanceRaw) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("System follows your phone's Light or Dark setting.")
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
                        Text("Cloud sync is off, so everything is saved on this phone only. \(FirebaseDiagnosis.problem ?? "Restart the app and try again.")")
                    } else {
                        Text("Changes save on this phone first and upload automatically when you're online.")
                    }
                }

                Section {
                    Button {
                        export.prepare()
                    } label: {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                            .frame(minHeight: 44, alignment: .leading)
                    }

                    Button(role: .destructive) {
                        showingDelete = true
                    } label: {
                        Label("Delete account and data", systemImage: "trash")
                            .frame(minHeight: 44, alignment: .leading)
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("The CSV file lists every transaction and opens in Excel or Numbers. Receipt photos are not included.")
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
                    Text("Adds 9 months of fake transactions and some budgets so you can see the charts. Debug builds only.")
                }
                #endif
            }
            .navigationTitle("Settings")
            .syncStatusBadge(container.sync)
            .confirmationDialog("Sign out of \(AppConstants.appName)?",
                                isPresented: $confirmingSignOut,
                                titleVisibility: .visible) {
                if hasUnsyncedChanges {
                    Button("Sync now") { sync.syncNow() }
                    Button("Sign out and lose these changes", role: .destructive) { session.signOut() }
                } else {
                    Button("Sign out", role: .destructive) { session.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(signOutMessage)
            }
            .sheet(isPresented: $export.isSharing) {
                if let url = export.fileURL {
                    ShareSheet(items: [url])
                        .presentationDetents([.medium, .large])
                }
            }
            .sheet(isPresented: $showingDelete) {
                DeleteAccountView(service: container.accountDeletion) {
                    showingDelete = false
                    lock.resetAfterAccountDeletion()
                    session.refreshSession()
                }
            }
            .alert("Export", isPresented: exportErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(export.errorMessage ?? "")
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
