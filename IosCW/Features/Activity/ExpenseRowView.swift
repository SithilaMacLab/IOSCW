import SwiftUI

struct ExpenseRowView: View {
    @ObservedObject var expense: Expense

    private var title: String {
        if !expense.merchant.isEmpty { return expense.merchant }
        return expense.category?.name ?? expense.type.title
    }

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(iconName: expense.category?.iconName ?? "questionmark.circle.fill",
                         colorHex: expense.category?.colorHex ?? "#8E8E93")

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text("\(expense.category?.name ?? "Uncategorised") · \(expense.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(amountText)
                .font(.body.monospacedDigit())
                .foregroundStyle(expense.type == .income ? Color.green : Color.primary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
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

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: size * 0.45))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color(hex: colorHex), in: Circle())
            .accessibilityHidden(true)
    }
}
