import SwiftUI

struct ActivityView: View {
    let container: AppContainer
    @StateObject private var viewModel: ActivityViewModel
    @State private var showingAdd = false
    @State private var showingFilter = false
    @State private var editing: Expense?

    init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(wrappedValue: ActivityViewModel(
            expenses: container.expenses,
            categories: container.categories))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.visibleTransactions.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Activity")
            .searchable(text: $viewModel.filter.searchText, prompt: "Search merchant, note or category")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Sort by", selection: $viewModel.sort) {
                            ForEach(ExpenseSort.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingFilter = true
                    } label: {
                        Label("Filter", systemImage: viewModel.filter.hasActiveFilters
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add transaction", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                ExpenseFormView(container: container)
            }
            .sheet(item: $editing) { expense in
                ExpenseFormView(container: container, editing: expense)
            }
            .sheet(isPresented: $showingFilter) {
                ActivityFilterView(filter: $viewModel.filter, categories: viewModel.categories)
            }
            .alert("Something went wrong", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var list: some View {
        List {
            ForEach(viewModel.visibleTransactions) { expense in
                Button {
                    editing = expense
                } label: {
                    ExpenseRowView(expense: expense)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        viewModel.delete(expense)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private var emptyState: some View {
        if viewModel.filter.isEmpty {
            ContentUnavailableView {
                Label("No transactions yet", systemImage: "list.bullet")
            } description: {
                Text("Add your first expense or income.")
            } actions: {
                Button("Add transaction") { showingAdd = true }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            ContentUnavailableView {
                Label("No matches", systemImage: "magnifyingglass")
            } description: {
                Text("Nothing fits the current search or filters.")
            } actions: {
                Button("Clear search and filters") { viewModel.filter = ExpenseFilter() }
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } })
    }
}

#Preview {
    ActivityView(container: .preview())
}
