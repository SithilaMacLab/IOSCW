import SwiftUI

struct ActivityFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: ExpenseFilter
    let categories: [ExpenseCategory]

    @State private var type: TransactionType?
    @State private var categoryID: UUID?
    @State private var useStart: Bool
    @State private var startDate: Date
    @State private var useEnd: Bool
    @State private var endDate: Date
    @State private var minText: String
    @State private var maxText: String

    init(filter: Binding<ExpenseFilter>, categories: [ExpenseCategory]) {
        _filter = filter
        self.categories = categories

        let current = filter.wrappedValue
        _type = State(initialValue: current.type)
        _categoryID = State(initialValue: current.categoryID)
        _useStart = State(initialValue: current.startDate != nil)
        _startDate = State(initialValue: current.startDate ?? Date())
        _useEnd = State(initialValue: current.endDate != nil)
        _endDate = State(initialValue: current.endDate ?? Date())
        _minText = State(initialValue: current.minAmount.map { String($0) } ?? "")
        _maxText = State(initialValue: current.maxAmount.map { String($0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Type", selection: $type) {
                        Text("All").tag(TransactionType?.none)
                        ForEach(TransactionType.allCases) { option in
                            Text(option.title).tag(TransactionType?.some(option))
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Category") {
                    Picker("Category", selection: $categoryID) {
                        Text("All categories").tag(UUID?.none)
                        ForEach(categories) { category in
                            Label(category.name, systemImage: category.iconName)
                                .tag(UUID?.some(category.id))
                        }
                    }
                }

                Section("Date range") {
                    Toggle("From", isOn: $useStart)
                    if useStart {
                        DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                    }
                    Toggle("To", isOn: $useEnd)
                    if useEnd {
                        DatePicker("End date", selection: $endDate, displayedComponents: .date)
                    }
                }

                Section("Amount (LKR)") {
                    TextField("Minimum", text: $minText)
                        .keyboardType(.decimalPad)
                    TextField("Maximum", text: $maxText)
                        .keyboardType(.decimalPad)
                }

                Section {
                    Button("Reset filters", role: .destructive) {
                        filter.clearFilters()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        apply()
                        dismiss()
                    }
                }
            }
        }
    }

    private func apply() {
        filter.type = type
        filter.categoryID = categoryID
        filter.startDate = useStart ? startDate : nil
        filter.endDate = useEnd ? endDate : nil
        filter.minAmount = parse(minText)
        filter.maxAmount = parse(maxText)
    }

    private func parse(_ text: String) -> Double? {
        let value = Double(text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
        return (value ?? 0) > 0 ? value : nil
    }
}
