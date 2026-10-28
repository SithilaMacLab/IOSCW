import SwiftUI

struct ExpenseFormView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ExpenseFormViewModel

    init(container: AppContainer, editing: Expense? = nil) {
        _viewModel = StateObject(wrappedValue: ExpenseFormViewModel(
            expenses: container.expenses,
            categories: container.categories,
            rates: container.rates,
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
                        Picker("Currency", selection: $viewModel.currencyCode) {
                            ForEach(viewModel.currencies) { currency in
                                Text("\(currency.code) · \(currency.name)").tag(currency.code)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()

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

                if viewModel.isForeign {
                    rateSection
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
            .task { await viewModel.currencyDidChange() }
            .onChange(of: viewModel.currencyCode) { _, _ in
                Task { await viewModel.currencyDidChange() }
            }
            .alert("Couldn't save", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var rateSection: some View {
        Section {
            switch viewModel.rateState {
            case .notNeeded:
                EmptyView()

            case .loading:
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Getting the latest rate…")
                        .foregroundStyle(.secondary)
                }

            case .ready(let rate):
                VStack(alignment: .leading, spacing: 4) {
                    Text("1 \(rate.currencyCode) = \(rate.rateToLKR.formatted(.number.precision(.fractionLength(2...4)))) LKR")
                        .font(.body.monospacedDigit())
                    sourceLabel(for: rate)
                }
                convertedRow

            case .unavailable:
                VStack(alignment: .leading, spacing: 8) {
                    Label("No saved rate and no connection.", systemImage: "wifi.slash")
                        .foregroundStyle(.orange)
                    HStack {
                        Text("1 \(viewModel.currencyCode) =")
                        TextField("LKR", text: $viewModel.manualRateText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("Exchange rate to LKR")
                        Text("LKR")
                    }
                    Button("Try again") {
                        Task { await viewModel.currencyDidChange() }
                    }
                }
                convertedRow
            }
        } header: {
            Text("Exchange rate")
        } footer: {
            Text("Converted to LKR when you save. Rates by ExchangeRate-API.")
        }
    }

    @ViewBuilder
    private var convertedRow: some View {
        if let converted = viewModel.convertedLKR {
            LabeledContent("Counted as", value: CurrencyFormatter.lkr(converted))
        }
    }

    private func sourceLabel(for rate: ExchangeRate) -> some View {
        Group {
            switch rate.source {
            case .live:
                Label {
                    Text("Updated \(rate.asOf, style: .relative) ago")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .foregroundStyle(.green)

            case .cached:
                Label {
                    Text("Offline: saved rate from \(rate.asOf, style: .relative) ago")
                } icon: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .foregroundStyle(.orange)

            case .stored:
                Label("Rate saved with this transaction", systemImage: "lock.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } })
    }
}

#Preview {
    ExpenseFormView(container: .preview())
}
