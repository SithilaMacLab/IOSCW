import SwiftUI

struct ExpenseFormView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ExpenseFormViewModel

    init(container: AppContainer, editing: Expense? = nil) {
        _viewModel = StateObject(wrappedValue: ExpenseFormViewModel(
            expenses: container.expenses,
            categories: container.categories,
            editing: editing))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $viewModel.type) {
                        ForEach(TransactionType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Details") {
                    HStack {
                        Text(viewModel.currencyCode)
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $viewModel.amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("Amount")
                    }

                    DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)

                    TextField("Merchant", text: $viewModel.merchant)

                    Picker("Category", selection: $viewModel.categoryID) {
                        Text("None").tag(UUID?.none)
                        ForEach(viewModel.categories) { category in
                            Label(category.name, systemImage: category.iconName)
                                .tag(UUID?.some(category.id))
                        }
                    }
                }

                Section("Note") {
                    TextField("Optional note", text: $viewModel.note, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .navigationTitle(viewModel.isEditing ? "Edit transaction" : "New transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if viewModel.save() { dismiss() }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .alert("Couldn't save", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } })
    }
}

#Preview {
    ExpenseFormView(container: .preview())
}
