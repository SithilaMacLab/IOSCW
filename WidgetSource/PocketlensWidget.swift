import SwiftUI
import WidgetKit

struct PocketlensEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?

    var content: PocketlensContent {
        guard let snapshot else { return .empty }
        guard Calendar.current.isDate(snapshot.month, equalTo: date, toGranularity: .month) else { return .stale }
        return .ready(snapshot)
    }
}

enum PocketlensContent {
    case empty
    case stale
    case ready(WidgetSnapshot)
}

struct PocketlensProvider: TimelineProvider {
    func placeholder(in context: Context) -> PocketlensEntry {
        PocketlensEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (PocketlensEntry) -> Void) {
        let snapshot: WidgetSnapshot? = context.isPreview ? .sample : WidgetStore.load()
        completion(PocketlensEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PocketlensEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetStore.load()
        var entries = [PocketlensEntry(date: now, snapshot: snapshot)]
        if let nextMonth = Calendar.current.dateInterval(of: .month, for: now)?.end {
            entries.append(PocketlensEntry(date: nextMonth, snapshot: snapshot))
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(3600))))
    }
}

struct PocketlensWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetStore.kind, provider: PocketlensProvider()) { entry in
            PocketlensWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Spending")
        .description("This month's spending against your budgets.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

struct PocketlensWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PocketlensEntry

    var body: some View {
        switch entry.content {
        case .empty:
            MessageView(text: "Open Pocketlens to see your spending.")
        case .stale:
            MessageView(text: "A new month has started. Open Pocketlens to refresh.")
        case .ready(let snapshot):
            switch family {
            case .systemMedium:
                MediumView(snapshot: snapshot)
            case .accessoryRectangular:
                RectangularView(snapshot: snapshot)
            case .accessoryCircular:
                CircularView(snapshot: snapshot)
            default:
                SmallView(snapshot: snapshot)
            }
        }
    }
}

private extension WidgetSnapshot {
    var status: BudgetStatus { BudgetStatus(progress: budgetProgress) }

    var hasBudgets: Bool { totalLimit > 0 }

    var percentText: String { "\(Int((budgetProgress * 100).rounded()))%" }

    func money(_ value: Double) -> String {
        value.formatted(.currency(code: currencyCode).precision(.fractionLength(0)))
    }
}

private func tint(for status: BudgetStatus) -> Color {
    switch status {
    case .onTrack: .green
    case .nearLimit: .orange
    case .overBudget: .red
    }
}

private struct MessageView: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "creditcard")
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SmallView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.month.formatted(.dateTime.month(.wide)))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Spent")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(snapshot.money(snapshot.spent))
                .font(.title3.bold().monospacedDigit())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .privacySensitive()

            Spacer(minLength: 0)

            if snapshot.hasBudgets {
                ProgressView(value: min(snapshot.budgetProgress, 1))
                    .tint(tint(for: snapshot.status))
                Label(snapshot.status.title, systemImage: snapshot.status.systemImage)
                    .font(.caption2.bold())
                    .foregroundStyle(tint(for: snapshot.status))
                Text("\(snapshot.percentText) of budgets used")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("No budgets set")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct MediumView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.month.formatted(.dateTime.month(.wide)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Spent")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(snapshot.money(snapshot.spent))
                    .font(.title3.bold().monospacedDigit())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .privacySensitive()

                if let expected = snapshot.expectedSpending {
                    Text("Expected \(snapshot.money(expected))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .privacySensitive()
                }

                Spacer(minLength: 0)

                if snapshot.hasBudgets {
                    Label(snapshot.status.title, systemImage: snapshot.status.systemImage)
                        .font(.caption2.bold())
                        .foregroundStyle(tint(for: snapshot.status))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                if snapshot.budgets.isEmpty {
                    Text("No budgets set")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.budgets.prefix(3)) { line in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(line.name)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text("\(Int((line.progress * 100).rounded()))%")
                                    .monospacedDigit()
                                    .privacySensitive()
                            }
                            .font(.caption2)
                            ProgressView(value: min(line.progress, 1))
                                .tint(tint(for: BudgetStatus(progress: line.progress)))
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct RectangularView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Spent this month")
                .font(.caption2)
            Text(snapshot.money(snapshot.spent))
                .font(.headline.monospacedDigit())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .privacySensitive()
            if snapshot.hasBudgets {
                Gauge(value: min(snapshot.budgetProgress, 1)) {
                    Text("Budgets")
                }
                .gaugeStyle(.accessoryLinearCapacity)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CircularView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        if snapshot.hasBudgets {
            Gauge(value: min(snapshot.budgetProgress, 1)) {
                Image(systemName: "creditcard")
            } currentValueLabel: {
                Text(snapshot.percentText)
                    .privacySensitive()
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .accessibilityLabel("Budgets used")
        } else {
            Image(systemName: "creditcard")
                .accessibilityLabel("No budgets set")
        }
    }
}

extension WidgetSnapshot {
    static let sample = WidgetSnapshot(
        month: Date(),
        currencyCode: "LKR",
        spent: 68_400,
        income: 150_000,
        totalLimit: 82_000,
        budgetedSpent: 64_900,
        expectedSpending: 91_000,
        budgets: [
            WidgetBudgetLine(id: "food", name: "Food & Dining", colorHex: "#FF9500", spent: 24_100, limit: 25_000),
            WidgetBudgetLine(id: "groceries", name: "Groceries", colorHex: "#34C759", spent: 21_300, limit: 30_000),
            WidgetBudgetLine(id: "transport", name: "Transport", colorHex: "#007AFF", spent: 6_500, limit: 15_000)
        ],
        updatedAt: Date())
}

#Preview(as: .systemSmall) {
    PocketlensWidget()
} timeline: {
    PocketlensEntry(date: Date(), snapshot: .sample)
}

#Preview(as: .systemMedium) {
    PocketlensWidget()
} timeline: {
    PocketlensEntry(date: Date(), snapshot: .sample)
}
