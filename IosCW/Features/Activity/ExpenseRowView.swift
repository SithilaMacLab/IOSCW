import SwiftUI

struct ExpenseRowView: View {
    @ObservedObject var expense: Expense

    private var title: String {
        if !expense.merchant.isEmpty { return expense.merchant }
        return expense.category?.name ?? expense.type.title
    }

    private var isForeign: Bool {
        expense.currencyCode != AppConstants.baseCurrencyCode
    }

    private var spokenLabel: String {
        var parts = [title,
                     "\(expense.type == .income ? "Income" : "Expense") of \(CurrencyFormatter.lkr(expense.amountLKR))"]
        if isForeign {
            parts.append("originally \(expense.amount.formatted(.currency(code: expense.currencyCode)))")
        }
        parts.append(expense.category?.name ?? "Uncategorised")
        parts.append(expense.date.formatted(date: .long, time: .omitted))
        return parts.joined(separator: ", ")
    }

    var body: some View {
        AdaptiveRow {
            CategoryIcon(iconName: expense.category?.iconName ?? "questionmark.circle.fill",
                         colorHex: expense.category?.colorHex ?? "#8E8E93")

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text("\(expense.category?.name ?? "Uncategorised") · \(expense.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } trailing: {
            VStack(alignment: .trailing, spacing: 2) {
                Text(amountText)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(expense.type == .income ? Color.green : Color.primary)
                if isForeign {
                    Text(expense.amount.formatted(.currency(code: expense.currencyCode)))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel)
    }

    private var amountText: String {
        let sign = expense.type == .income ? "+" : "−"
        return "\(sign)\(CurrencyFormatter.lkr(expense.amountLKR))"
    }
}

struct CategoryIcon: View {
    let iconName: String
    let colorHex: String
    var size: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1

    private var scaledSize: CGFloat { size * min(textScale, 1.6) }

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: scaledSize * 0.45))
            .foregroundStyle(.white)
            .frame(width: scaledSize, height: scaledSize)
            .background(Color(hex: colorHex), in: Circle())
            .accessibilityHidden(true)
    }
}
