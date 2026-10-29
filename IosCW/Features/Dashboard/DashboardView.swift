import Charts
import SwiftUI

struct DashboardView: View {
    let container: AppContainer
    @StateObject private var viewModel: DashboardViewModel

    init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(wrappedValue: DashboardViewModel(expenses: container.expenses))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.hasAnyTransactions {
                    ScrollView {
                        VStack(spacing: 16) {
                            summaryCards
                            forecastCard
                            categoryCard
                            placesCard
                            trendCard
                        }
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground))
                } else {
                    ContentUnavailableView("Nothing to show yet", systemImage: "chart.pie",
                                           description: Text("Add a transaction on the Activity tab and your charts will appear here."))
                }
            }
            .navigationTitle("Dashboard")
        }
    }

    private var summaryCards: some View {
        VStack(spacing: 12) {
            Text(Date().formatted(.dateTime.month(.wide).year()))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                SummaryTile(title: "Income", value: viewModel.monthIncome,
                            systemImage: "arrow.down.circle.fill", tint: .green)
                SummaryTile(title: "Spent", value: viewModel.monthExpenses,
                            systemImage: "arrow.up.circle.fill", tint: .red)
            }
            SummaryTile(title: "Balance", value: viewModel.balance,
                        systemImage: "scalemass.fill", tint: viewModel.balance >= 0 ? .blue : .orange)
        }
    }

    private var forecastCard: some View {
        ChartCard(title: "Predicted and actual") {
            switch viewModel.forecast {
            case .notEnoughData(let months, let needed):
                Label("Not enough data yet. The forecast needs spending in each of the last \(needed) months, and you have \(months).",
                      systemImage: "chart.line.uptrend.xyaxis")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .ready(let result):
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Expected spending")
                        Spacer()
                        Text(CurrencyFormatter.lkr(result.expenses.expected))
                            .font(.headline.monospacedDigit())
                    }
                    .font(.subheadline)

                    ProgressView(value: result.expenses.progress)
                        .tint(.red)
                        .accessibilityLabel("Spent so far compared with the forecast")
                        .accessibilityValue("\(Int((result.expenses.progress * 100).rounded())) percent")

                    Text("Spent so far \(CurrencyFormatter.lkr(result.expenses.soFar)). Open the Forecast tab for the full picture.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var placesCard: some View {
        ChartCard(title: "Where you spend") {
            if viewModel.topAreas.isEmpty {
                Label("Scan a receipt with location on to see which areas take the most.",
                      systemImage: "mappin.slash")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(viewModel.topAreas.enumerated()), id: \.element.id) { index, area in
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.footnote.bold())
                                .frame(width: 26, height: 26)
                                .background(Color.red.opacity(0.2), in: Circle())
                                .accessibilityHidden(true)
                            Text(area.name)
                            Spacer()
                            Text(CurrencyFormatter.lkr(area.total))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            NavigationLink {
                SpendingMapView(container: container)
            } label: {
                Label("See the map", systemImage: "map")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
        }
    }

    private var categoryCard: some View {
        ChartCard(title: "Spending by category") {
            if viewModel.categoryTotals.isEmpty {
                Text("No expenses this month.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                Chart(viewModel.categoryTotals) { item in
                    SectorMark(
                        angle: .value("Spent", item.total),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(by: .value("Category", item.name))
                }
                .chartForegroundStyleScale(
                    domain: viewModel.categoryTotals.map(\.name),
                    range: viewModel.categoryTotals.map { Color(hex: $0.colorHex) })
                .chartLegend(.hidden)
                .frame(height: 220)
                .accessibilityLabel("Donut chart of this month's spending by category")

                VStack(spacing: 10) {
                    ForEach(viewModel.categoryTotals) { item in
                        HStack(spacing: 10) {
                            CategoryIcon(iconName: item.iconName, colorHex: item.colorHex, size: 28)
                            Text(item.name)
                            Spacer()
                            Text(CurrencyFormatter.lkr(item.total))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private var trendCard: some View {
        ChartCard(title: "Last 6 months") {
            Chart(viewModel.trend) { point in
                BarMark(
                    x: .value("Month", point.month, unit: .month),
                    y: .value("Amount", point.amount)
                )
                .position(by: .value("Type", point.kind))
                .foregroundStyle(by: .value("Type", point.kind))
            }
            .chartForegroundStyleScale(["Income": Color.green, "Expenses": Color.red])
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
            .accessibilityLabel("Bar chart of income and expenses for the last six months")
        }
    }
}

private struct SummaryTile: View {
    let title: String
    let value: Double
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(CurrencyFormatter.lkr(value))
                    .font(.headline.monospacedDigit())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

struct ChartCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    DashboardView(container: .preview())
}
