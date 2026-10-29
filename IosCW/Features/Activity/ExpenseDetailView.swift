import SwiftUI

struct ExpenseDetailView: View {
    @ObservedObject var expense: Expense
    let onEdit: () -> Void

    private var title: String {
        if !expense.merchant.isEmpty { return expense.merchant }
        return expense.category?.name ?? expense.type.title
    }

    private var receiptImage: UIImage? {
        expense.receiptImageData.flatMap { UIImage(data: $0) }
    }

    private var isForeign: Bool {
        expense.currencyCode != AppConstants.baseCurrencyCode
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryCard
                detailsCard
                if let image = receiptImage {
                    receiptCard(image)
                }
            }
            .padding()
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit", action: onEdit)
            }
        }
    }

    private var summaryCard: some View {
        ChartCard(title: expense.type.title) {
            HStack(spacing: 12) {
                CategoryIcon(iconName: expense.category?.iconName ?? "questionmark.circle.fill",
                             colorHex: expense.category?.colorHex ?? "#8E8E93",
                             size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(CurrencyFormatter.lkr(expense.amountLKR))
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(expense.type == .income ? Color.green : Color.primary)
                    if isForeign {
                        Text("\(expense.amount.formatted(.currency(code: expense.currencyCode))) at \(expense.exchangeRate.formatted(.number.precision(.fractionLength(2)))) LKR each")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var detailsCard: some View {
        ChartCard(title: "Details") {
            VStack(spacing: 12) {
                row("Date", expense.date.formatted(date: .complete, time: .omitted))
                row("Category", expense.category?.name ?? "Uncategorised")
                if !expense.merchant.isEmpty {
                    row("Merchant", expense.merchant)
                }
                if let place = expense.place {
                    row("Place", place.name ?? "Saved location")
                }
                if !expense.note.isEmpty {
                    row("Note", expense.note)
                }
            }
        }
    }

    private func receiptCard(_ image: UIImage) -> some View {
        ChartCard(title: "Receipt") {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Photo of the receipt")
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        AdaptiveRow(spacing: 8) {
            Text(label)
                .foregroundStyle(.secondary)
        } trailing: {
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}
