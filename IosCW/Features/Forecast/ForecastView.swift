import Charts
import SwiftUI

private enum ForecastMode: String, CaseIterable, Identifiable {
    case thisMonth
    case nextMonth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thisMonth: "This month"
        case .nextMonth: "Next month"
        }
    }
}

struct ForecastView: View {
    @StateObject private var viewModel: ForecastViewModel
    @StateObject private var nextMonth: NextMonthViewModel
    @State private var mode: ForecastMode = .thisMonth
    private let container: AppContainer
    private let sync: SyncEngine

    private let columns = [GridItem(.adaptive(minimum: 340), spacing: 16, alignment: .top)]

    init(container: AppContainer) {
        self.container = container
        sync = container.sync
        _viewModel = StateObject(wrappedValue: ForecastViewModel(expenses: container.expenses,
                                                                 budgets: container.budgets))
        _nextMonth = StateObject(wrappedValue: NextMonthViewModel(service: container.predictor))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.outcome {
                case .notEnoughData(let months, let needed):
                    ContentUnavailableView {
                        Label("Not enough data yet", systemImage: "chart.line.uptrend.xyaxis")
                    } description: {
                        Text("The forecast learns from the last \(needed) months of spending. You have \(months) of \(needed) so far. Keep adding transactions and it will appear here.")
                    }
                case .ready(let result):
                    ScrollView {
                        VStack(spacing: 16) {
                            Picker("Period", selection: $mode) {
                                ForEach(ForecastMode.allCases) { option in
                                    Text(option.title).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)

                            switch mode {
                            case .thisMonth:
                                LazyVGrid(columns: columns, spacing: 16) {
                                    summaryCard(result)
                                    if !viewModel.alerts.isEmpty {
                                        alertsCard
                                    }
                                    chartCard(result)
                                    categoryCard
                                    footnote
                                }
                            case .nextMonth:
                                NextMonthSection(viewModel: nextMonth, container: container)
                            }
                        }
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Forecast")
            .syncStatusBadge(sync)
        }
    }

    private func summaryCard(_ result: ForecastResult) -> some View {
        ChartCard(title: "\(result.month.formatted(.dateTime.month(.wide))) by the end of the month") {
            VStack(spacing: 14) {
                FigureRow(title: "Income", systemImage: "arrow.down.circle.fill", tint: .green,
                          figure: result.income)
                Divider()
                FigureRow(title: "Spending", systemImage: "arrow.up.circle.fill", tint: .red,
                          figure: result.expenses)
                Divider()
                AdaptiveRow {
                    Image(systemName: "scalemass.fill")
                        .font(.title3)
                        .foregroundStyle(result.leftOver >= 0 ? Color.blue : Color.orange)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    Text("Left over")
                        .font(.subheadline)
                } trailing: {
                    Text(CurrencyFormatter.lkr(result.leftOver))
                        .font(.headline.monospacedDigit())
                }
                .accessibilityElement(children: .combine)
            }

            Text("Day \(result.dayOfMonth) of \(result.daysInMonth). Predictions get steadier as the month goes on.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var alertsCard: some View {
        ChartCard(title: "Early warnings") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(viewModel.alerts) { alert in
                    Label(alert.message, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                        .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func chartCard(_ result: ForecastResult) -> some View {
        ChartCard(title: "Spent and expected") {
            Chart(viewModel.bars) { bar in
                BarMark(
                    x: .value("Month", bar.month, unit: .month),
                    y: .value("Amount", bar.amount)
                )
                .foregroundStyle(by: .value("Series", bar.series))
            }
            .chartForegroundStyleScale(
                domain: [ForecastBar.spent, ForecastBar.expectedRest],
                range: [Color.red, Color.red.opacity(0.35)])
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(CurrencyFormatter.compact(amount))
                        }
                    }
                }
            }
            .frame(height: 220)
            .accessibilityLabel("Bar chart of spending for the last three months and this month, with the expected rest of this month")
            .accessibilityValue("This month so far \(CurrencyFormatter.lkr(result.expenses.soFar)), expected \(CurrencyFormatter.lkr(result.expenses.expected)) by the end of the month")
        }
    }

    private var categoryCard: some View {
        ChartCard(title: "Expected by category") {
            if viewModel.outlooks.isEmpty {
                Text("No spending to forecast yet.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 16) {
                    ForEach(viewModel.outlooks) { outlook in
                        CategoryOutlookRow(outlook: outlook)
                    }
                }
            }
        }
    }

    private var footnote: some View {
        Text("How it works: for each of the last 3 months Pocketlens looks at what was added after today's date in the month, gives recent months more weight, and adds that to what you have already recorded. It is calculated on this phone and nothing is sent to a server.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FigureRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    let figure: ForecastFigure

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
                Text(CurrencyFormatter.lkr(figure.expected))
                    .font(.headline.monospacedDigit())
            }
            ProgressView(value: figure.progress)
                .tint(tint)
                .accessibilityLabel("\(title) so far compared with the forecast")
                .accessibilityValue("\(Int((figure.progress * 100).rounded())) percent")
            Text("So far \(CurrencyFormatter.lkr(figure.soFar)). Likely between \(CurrencyFormatter.lkr(figure.low)) and \(CurrencyFormatter.lkr(figure.high)).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CategoryOutlookRow: View {
    let outlook: CategoryOutlook

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AdaptiveRow(spacing: 10) {
                CategoryIcon(iconName: outlook.forecast.iconName, colorHex: outlook.forecast.colorHex, size: 28)
                Text(outlook.forecast.name)
            } trailing: {
                Text(CurrencyFormatter.lkr(outlook.forecast.figure.expected))
                    .monospacedDigit()
            }
            .font(.subheadline)

            if let limit = outlook.limit, let status = outlook.status {
                ProgressView(value: min(BudgetMath.progress(spent: outlook.forecast.figure.expected, limit: limit), 1))
                    .tint(tint(for: status))
                Label("Forecast: \(status.title). Limit \(CurrencyFormatter.lkr(limit)).",
                      systemImage: status.systemImage)
                    .font(.caption)
                    .foregroundStyle(tint(for: status))
            } else {
                Text("So far \(CurrencyFormatter.lkr(outlook.forecast.figure.soFar)). No budget set.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func tint(for status: BudgetStatus) -> Color {
        switch status {
        case .onTrack: .green
        case .nearLimit: .orange
        case .overBudget: .red
        }
    }
}

#Preview {
    ForecastView(container: .preview())
}
