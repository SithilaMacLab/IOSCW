import SwiftUI

struct BudgetsView: View {
    let container: AppContainer
    @StateObject private var viewModel: BudgetsViewModel
    @State private var showingAdd = false
    @State private var editing: BudgetItem?

    init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(wrappedValue: BudgetsViewModel(
            budgets: container.budgets,
            expenses: container.expenses,
            categories: container.categories))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.items.isEmpty {
                    ContentUnavailableView {
                        Label("No budgets yet", systemImage: "target")
                    } description: {
                        Text("Set a monthly limit for a category to get a warning before you overspend.")
                    } actions: {
                        Button("Add budget") { showingAdd = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        Section("This month") {
                            ForEach(viewModel.items) { item in
                                Button {
                                    editing = item
                                } label: {
                                    BudgetRowView(item: item)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        viewModel.delete(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Budgets")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add budget", systemImage: "plus")
                    }
                    .disabled(viewModel.categoriesWithoutBudget.isEmpty)
                }
            }
            .sheet(isPresented: $showingAdd) {
                BudgetFormView(viewModel: viewModel, editing: nil)
            }
            .sheet(item: $editing) { item in
                BudgetFormView(viewModel: viewModel, editing: item)
            }
            .alert("Something went wrong", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } })
    }
}

extension BudgetStatus {
    var color: Color {
        switch self {
        case .onTrack: .green
        case .nearLimit: .orange
        case .overBudget: .red
        }
    }
}

struct BudgetRowView: View {
    let item: BudgetItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AdaptiveRow {
                CategoryIcon(iconName: item.category.iconName, colorHex: item.category.colorHex, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.category.name)
                        .font(.body)
                    Text("\(CurrencyFormatter.lkr(item.spent)) of \(CurrencyFormatter.lkr(item.limit))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } trailing: {
                Label(item.status.title, systemImage: item.status.systemImage)
                    .font(.caption.bold())
                    .foregroundStyle(item.status.color)
            }

            ProgressView(value: min(item.progress, 1))
                .tint(item.status.color)

            Text(item.remaining >= 0
                 ? "\(CurrencyFormatter.lkr(item.remaining)) left"
                 : "\(CurrencyFormatter.lkr(-item.remaining)) over")
                .font(.caption)
                .foregroundStyle(item.remaining >= 0 ? Color.secondary : item.status.color)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(Int(item.progress * 100)) percent used")
    }
}

#Preview {
    BudgetsView(container: .preview())
}
