import SwiftUI

struct DeleteAccountView: View {
    let onDeleted: () -> Void
    @StateObject private var viewModel: DeleteAccountViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var passwordFocused: Bool

    init(service: AccountDeleting, onDeleted: @escaping () -> Void) {
        self.onDeleted = onDeleted
        _viewModel = StateObject(wrappedValue: DeleteAccountViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Your account and sign-in", systemImage: "person.crop.circle.badge.xmark")
                    Label("Every transaction, budget and category in the cloud", systemImage: "icloud.slash")
                    Label("Everything saved on this phone, including receipt photos and places", systemImage: "iphone.slash")
                } header: {
                    Text("This will permanently delete")
                } footer: {
                    Text("This cannot be undone. Export your transactions to CSV first if you want to keep a copy.")
                }

                Section {
                    SecureField("Password", text: $viewModel.password)
                        .textContentType(.password)
                        .focused($passwordFocused)
                        .submitLabel(.done)
                        .frame(minHeight: 44)
                } header: {
                    Text("Confirm it is you")
                } footer: {
                    Text("Enter your password to continue.")
                }

                if let message = viewModel.errorMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        passwordFocused = false
                        viewModel.isConfirming = true
                    } label: {
                        HStack {
                            if viewModel.isWorking {
                                ProgressView()
                                Text("Deleting…")
                            } else {
                                Text("Delete account and data")
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .disabled(!viewModel.canSubmit)
                }
            }
            .navigationTitle("Delete account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isWorking)
                }
            }
            .confirmationDialog("Delete your account and all data?",
                                isPresented: $viewModel.isConfirming,
                                titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) {
                    Task {
                        if await viewModel.delete() {
                            onDeleted()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
            .interactiveDismissDisabled(viewModel.isWorking)
        }
    }
}

#Preview {
    DeleteAccountView(service: AppContainer.preview(withSamples: false).accountDeletion, onDeleted: {})
}
