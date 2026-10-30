import SwiftUI

struct BudgetPlanView: View {
    @StateObject private var viewModel: BudgetPlanViewModel
    @State private var confirming = false

    private let month: Date
    private let columns = [GridItem(.adaptive(minimum: 340), spacing: 16, alignment: .top)]

    init(forecast: NextMonthForecast, container: AppContainer) {
        month = forecast.month
        _viewModel = StateObject(wrappedValue: BudgetPlanViewModel(forecast: forecast,
                                                                  budgets: container.budgets,
                                                                  categories: container.categories))
    }

    private var plan: BudgetPlan { viewModel.plan }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                goalCard
                if !plan.flexibleLines.isEmpty {
                    linesCard(title: "Flexible spending",
                              note: plan.hasIncome
                                  ? "Trimmed only as much as needed to reach your goal, never below 60% of what you normally spend."
                                  : "Set to your expected spending.",
                              lines: plan.flexibleLines)
                }
                if !plan.essentialLines.isEmpty {
                    linesCard(title: "Essentials",
                              note: "Kept at the forecast plus a 5% buffer, because these bills still have to be paid.",
                              lines: plan.essentialLines)
                }
                applyCard
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Budget plan")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Something went wrong", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .confirmationDialog("Replace your budgets with this plan?",
                            isPresented: $confirming,
                            titleVisibility: .visible) {
            Button("Apply plan") { viewModel.apply() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Limits will be set for \(plan.lines.count) categories. You can change any of them later on the Budgets tab.")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } })
    }

    private var goalCard: some View {
        ChartCard(title: "\(month.formatted(.dateTime.month(.wide))) savings goal") {
            if plan.hasIncome {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Save \(Int((plan.savingsRate * 100).rounded()))% of income, about \(CurrencyFormatter.lkr(plan.goal))")
                        .font(.headline)

                    Slider(value: $viewModel.savingsRate,
                           in: 0...BudgetPlanner.maximumSavingsRate,
                           step: 0.05)
                        .accessibilityLabel("Savings goal")
                        .accessibilityValue("\(Int((plan.savingsRate * 100).rounded())) percent, \(CurrencyFormatter.lkr(plan.goal))")

                    summaryRow("Expected income", CurrencyFormatter.lkr(plan.income))
                    summaryRow("Planned spending", CurrencyFormatter.lkr(plan.plannedSpending))
                    summaryRow("Planned savings", CurrencyFormatter.lkr(plan.plannedSavings))

                    if plan.isFeasible {
                        Label("This goal fits your expected spending.", systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    } else {
                        Label("This goal is too high for next month. The closest you can get is about \(Int((plan.achievedRate * 100).rounded()))%, which is \(CurrencyFormatter.lkr(plan.shortfall)) short.",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                }
            } else {
                Label("No income was recorded in your recent months, so a savings goal can't be set. The limits below follow your expected spending.",
                      systemImage: "info.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        AdaptiveRow(spacing: 4) {
            Text(label)
                .foregroundStyle(.secondary)
        } trailing: {
            Text(value)
                .monospacedDigit()
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }

    private func linesCard(title: String, note: String, lines: [PlanLine]) -> some View {
        ChartCard(title: title) {
            VStack(alignment: .leading, spacing: 14) {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ForEach(lines) { line in
                    lineRow(line)
                }
            }
        }
    }

    private func lineRow(_ line: PlanLine) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            AdaptiveRow(spacing: 10) {
                CategoryIcon(iconName: line.iconName, colorHex: line.colorHex, size: 28)
                Text(line.name)
            } trailing: {
                Text(CurrencyFormatter.lkr(line.limit))
                    .font(.headline.monospacedDigit())
            }
            .font(.subheadline)

            Text(changeText(line))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func changeText(_ line: PlanLine) -> String {
        var text = "Expected \(CurrencyFormatter.lkr(line.forecast))"
        if line.change <= -1 {
            text += " · \(CurrencyFormatter.lkr(-line.change)) less"
        } else if line.change >= 1 {
            text += " · \(CurrencyFormatter.lkr(line.change)) buffer"
        }
        if let current = viewModel.currentLimits[line.id] {
            text += " · now \(CurrencyFormatter.lkr(current))"
        }
        return text
    }

    private var applyCard: some View {
        ChartCard(title: "Use this plan") {
            VStack(alignment: .leading, spacing: 12) {
                if let count = viewModel.appliedCount {
                    Label("Budgets updated for \(count) categories. See them on the Budgets tab.",
                          systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }

                Button {
                    confirming = true
                } label: {
                    Label("Apply as my budgets", systemImage: "target")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(plan.lines.isEmpty)

                Text("Existing limits for these categories are replaced. Categories not in the plan keep their budget.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
