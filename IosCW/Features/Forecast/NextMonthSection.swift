import SwiftUI

struct NextMonthSection: View {
    @ObservedObject var viewModel: NextMonthViewModel
    let container: AppContainer

    var body: some View {
        if let forecast = viewModel.forecast {
            MasonryLayout {
                summaryCard(forecast)
                learningCard(forecast)
                categoryCard(forecast)
                planCard(forecast)
            }
        }
    }

    private func percent(_ value: Double) -> Int {
        Int((value * 100).rounded())
    }

    private func summaryCard(_ forecast: NextMonthForecast) -> some View {
        ChartCard(title: "\(forecast.month.formatted(.dateTime.month(.wide).year())) expected") {
            VStack(spacing: 14) {
                if forecast.income.value >= 1 {
                    OutlookRow(title: "Income", systemImage: "arrow.down.circle.fill", tint: .green,
                               forecast: forecast.income)
                    Divider()
                }
                OutlookRow(title: "Spending", systemImage: "arrow.up.circle.fill", tint: .red,
                           forecast: forecast.expenses)
                if forecast.income.value >= 1 {
                    Divider()
                    AdaptiveRow {
                        Image(systemName: "scalemass.fill")
                            .font(.title3)
                            .foregroundStyle(forecast.leftOver >= 0 ? Color.blue : Color.orange)
                            .frame(width: 28)
                            .accessibilityHidden(true)
                        Text("Left over")
                            .font(.subheadline)
                    } trailing: {
                        Text(CurrencyFormatter.lkr(forecast.leftOver))
                            .font(.headline.monospacedDigit())
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func learningCard(_ forecast: NextMonthForecast) -> some View {
        ChartCard(title: "How the model learned") {
            VStack(alignment: .leading, spacing: 10) {
                Label("Trained on \(forecast.monthsOfHistory) months of your own spending",
                      systemImage: "brain.head.profile")
                    .font(.subheadline)

                if let error = forecast.expenses.error {
                    Label("Past predictions were off by about \(percent(error))% on average, tested on \(forecast.expenses.backtestPoints) past \(forecast.expenses.backtestPoints == 1 ? "month" : "months").",
                          systemImage: "scope")
                        .font(.subheadline)
                } else {
                    Label("Accuracy can be measured after one more month of history.",
                          systemImage: "scope")
                        .font(.subheadline)
                }

                Text(phaseText(forecast))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let trainedAt = viewModel.training.trainedAt {
                    Text("Last trained \(trainedAt, style: .date). It retrains by itself every new month and whenever your past months change. Nothing leaves this phone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func phaseText(_ forecast: NextMonthForecast) -> String {
        switch forecast.phase {
        case .basic:
            "Using a weighted average of your last 3 months. With a 4th month the app can start measuring how accurate it is."
        case .early:
            "The accuracy is an early estimate. After 6 months of history the app compares five methods on your own past months and picks the best one for each category."
        case .learned:
            "The app compared five methods on your own past months and kept the one with the smallest error for each category."
        }
    }

    private func categoryCard(_ forecast: NextMonthForecast) -> some View {
        ChartCard(title: "Expected by category") {
            if forecast.categories.isEmpty {
                Text("No spending to forecast yet.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 16) {
                    ForEach(forecast.categories) { category in
                        categoryRow(category)
                    }
                }
            }
        }
    }

    private func categoryRow(_ category: CategoryPrediction) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            AdaptiveRow(spacing: 10) {
                CategoryIcon(iconName: category.iconName, colorHex: category.colorHex, size: 28)
                Text(category.name)
            } trailing: {
                Text(CurrencyFormatter.lkr(category.forecast.value))
                    .monospacedDigit()
            }
            .font(.subheadline)

            Text(detail(for: category))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func detail(for category: CategoryPrediction) -> String {
        var parts = ["Last month \(CurrencyFormatter.lkr(category.lastMonth))"]
        if let model = category.forecast.model {
            parts.append(model.title)
        }
        if let error = category.forecast.error {
            parts.append("about ±\(percent(max(error, 0.05)))%")
        }
        return parts.joined(separator: " · ")
    }

    private func planCard(_ forecast: NextMonthForecast) -> some View {
        ChartCard(title: "Budget plan") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Turn this forecast into spending limits for next month, with a savings goal you choose.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                NavigationLink {
                    BudgetPlanView(forecast: forecast, container: container)
                } label: {
                    Label("Plan next month's budget", systemImage: "list.clipboard")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            }
        }
    }
}

private struct OutlookRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    let forecast: SeriesForecast

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AdaptiveRow {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.subheadline)
            } trailing: {
                Text(CurrencyFormatter.lkr(forecast.value))
                    .font(.headline.monospacedDigit())
            }

            Text("Likely between \(CurrencyFormatter.lkr(forecast.low)) and \(CurrencyFormatter.lkr(forecast.high)).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
