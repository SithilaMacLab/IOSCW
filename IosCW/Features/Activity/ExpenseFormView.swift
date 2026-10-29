import SwiftUI

struct ExpenseFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel: ExpenseFormViewModel

    init(container: AppContainer, editing: Expense? = nil, prefill: ReceiptPrefill? = nil) {
        _viewModel = StateObject(wrappedValue: ExpenseFormViewModel(
            expenses: container.expenses,
            categories: container.categories,
            rates: container.rates,
            location: container.location,
            editing: editing,
            prefill: prefill))
    }

    var body: some View {
        NavigationStack {
            Form {
                if let thumbnail = viewModel.receiptThumbnail {
                    receiptSection(thumbnail)
                }

                Section {
                    Picker("Type", selection: $viewModel.type) {
                        ForEach(TransactionType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Details") {
                    flaggable([ReviewHint(.amount, "Check the amount"),
                               ReviewHint(.currency, "Check the currency")]) {
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
                    }

                    flaggable([ReviewHint(.date, "Check the date")]) {
                        DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
                    }

                    flaggable([ReviewHint(.merchant, "Check the merchant name")]) {
                        TextField("Merchant", text: $viewModel.merchant)
                    }

                    flaggable([ReviewHint(.category, "Pick or confirm a category")]) {
                        Picker("Category", selection: $viewModel.categoryID) {
                            Text("None").tag(UUID?.none)
                            ForEach(viewModel.categories) { category in
                                Label(category.name, systemImage: category.iconName)
                                    .tag(UUID?.some(category.id))
                            }
                        }
                    }
                }

                if viewModel.showsPlaceSection {
                    placeSection
                }

                if viewModel.isForeign {
                    rateSection
                }

                Section("Note") {
                    TextField("Optional note", text: $viewModel.note, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .navigationTitle(title)
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
            .task { await viewModel.captureLocationForScan() }
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

    private var title: String {
        if viewModel.isEditing { return "Edit transaction" }
        return viewModel.isReviewingScan ? "Review receipt" : "New transaction"
    }

    private func receiptSection(_ thumbnail: UIImage) -> some View {
        Section {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Receipt photo")

            if viewModel.isReviewingScan {
                if viewModel.flagged.isEmpty {
                    Label("Everything looks right. Check it and save.", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    Label(flaggedSummary, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        } header: {
            Text("Receipt")
        } footer: {
            if viewModel.isReviewingScan {
                Text("Read on this phone. Fields marked with a warning were hard to read, so please check them.")
            } else {
                Text("The photo stays on this phone and is not uploaded.")
            }
        }
    }

    @ViewBuilder
    private var placeSection: some View {
        Section {
            switch viewModel.locationState {
            case .notSet:
                if viewModel.canAddPlace {
                    Button {
                        Task { await viewModel.captureLocation() }
                    } label: {
                        Label("Add current place", systemImage: "location")
                    }
                    .frame(minHeight: 44)
                }

            case .locating:
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Finding where you are…")
                        .foregroundStyle(.secondary)
                }

            case .located(let place):
                Label(place.name ?? "Place saved", systemImage: "mappin.circle.fill")
                    .foregroundStyle(.green)
                Button("Remove place", role: .destructive) {
                    viewModel.removeLocation()
                }
                .frame(minHeight: 44)

            case .denied:
                Label("Location is off for Pocketlens, so this will be saved without a place.",
                      systemImage: "location.slash")
                    .foregroundStyle(.orange)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .frame(minHeight: 44)

            case .unavailable:
                Label("Couldn't find your location.", systemImage: "location.slash")
                    .foregroundStyle(.orange)
                Button("Try again") {
                    Task { await viewModel.captureLocation() }
                }
                .frame(minHeight: 44)
            }
        } header: {
            Text("Place")
        } footer: {
            Text("Used for the Where you spend map. You can remove it at any time.")
        }
    }

    private var flaggedSummary: String {
        let count = viewModel.flagged.count
        return "Please check \(count) \(count == 1 ? "field" : "fields") marked below."
    }

    private struct ReviewHint: Identifiable {
        let field: ReviewField
        let text: String

        var id: String { text }

        init(_ field: ReviewField, _ text: String) {
            self.field = field
            self.text = text
        }
    }

    private func flaggable<Content: View>(_ hints: [ReviewHint],
                                          @ViewBuilder content: () -> Content) -> some View {
        let active = hints.filter { viewModel.flagged.contains($0.field) }
        return VStack(alignment: .leading, spacing: 4) {
            content()
            ForEach(active) { hint in
                Label(hint.text, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .listRowBackground(active.isEmpty ? Color(.secondarySystemGroupedBackground) : Color.orange.opacity(0.15))
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
