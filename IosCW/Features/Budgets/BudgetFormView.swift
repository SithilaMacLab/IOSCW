import SwiftUI

struct BudgetFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: BudgetsViewModel
    let editing: BudgetItem?

    @State private var selectedCategoryID: UUID?
    @State private var limitText: String

    init(viewModel: BudgetsViewModel, editing: BudgetItem?) {
        self.viewModel = viewModel
        self.editing = editing
        _selectedCategoryID = State(initialValue: editing?.category.id)
        _limitText = State(initialValue: editing.map {
            $0.limit.formatted(.number.grouping(.never).precision(.fractionLength(0...2)))
        } ?? "")
    }

    private var limit: Double? {
        Double(limitText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
    }

    private var category: ExpenseCategory? {
        editing?.category ?? viewModel.categoriesWithoutBudget.first { $0.id == selectedCategoryID }
    }

    private var canSave: Bool { category != nil && (limit ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    if let editing {
                        Label(editing.category.name, systemImage: editing.category.iconName)
                    } else {
                        Picker("Category", selection: $selectedCategoryID) {
                            Text("Choose…").tag(UUID?.none)
                            ForEach(viewModel.categoriesWithoutBudget) { category in
                                Label(category.name, systemImage: category.iconName)
                                    .tag(UUID?.some(category.id))
                            }
                        }
                    }
                }

                Section("Monthly limit") {
                    HStack {
                        Text(AppConstants.baseCurrencyCode)
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $limitText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("Monthly limit")
                    }
                }
            }
            .navigationTitle(editing == nil ? "New budget" : "Edit budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let category, viewModel.setLimit(limit, for: category) {
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
