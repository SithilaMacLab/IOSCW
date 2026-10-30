import PhotosUI
import SwiftUI

struct ActivityView: View {
    let container: AppContainer
    @StateObject private var viewModel: ActivityViewModel
    @State private var showingAdd = false
    @State private var showingFilter = false
    @State private var showingScanner = false
    @State private var showingPhotoPicker = false
    @State private var photoSelection: PhotosPickerItem?
    @State private var pendingImages: [UIImage]?
    @State private var scannedReceipt: ScannedReceipt?
    @State private var editing: Expense?
    @State private var selectedID: UUID?
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(wrappedValue: ActivityViewModel(
            expenses: container.expenses,
            categories: container.categories))
    }

    private var usesSplitView: Bool { sizeClass == .regular }

    private var selectedExpense: Expense? {
        viewModel.allTransactions.first { $0.id == selectedID }
    }

    var body: some View {
        Group {
            if usesSplitView {
                NavigationSplitView {
                    listColumn
                } detail: {
                    detailColumn
                }
            } else {
                NavigationStack {
                    listColumn
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            ExpenseFormView(container: container)
        }
        .fullScreenCover(isPresented: $showingScanner, onDismiss: openPendingScan) {
            DocumentScannerView(
                onFinish: { images in
                    pendingImages = images
                    showingScanner = false
                },
                onCancel: { showingScanner = false },
                onError: { _ in
                    showingScanner = false
                    viewModel.errorMessage = "The camera couldn't scan that receipt."
                })
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $photoSelection, matching: .images)
        .onChange(of: photoSelection) { _, item in
            guard let item else { return }
            Task { await loadPhoto(item) }
        }
        .sheet(item: $scannedReceipt) { receipt in
            ReceiptFlowView(container: container, images: receipt.images)
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

    private var listColumn: some View {
        Group {
            if viewModel.visibleTransactions.isEmpty {
                emptyState
            } else if usesSplitView {
                selectableList
            } else {
                list
            }
        }
        .navigationTitle("Activity")
        .syncStatusBadge(container.sync)
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
                Menu {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add manually", systemImage: "square.and.pencil")
                    }

                    Button {
                        showingScanner = true
                    } label: {
                        Label("Scan a receipt", systemImage: "doc.viewfinder")
                    }
                    .disabled(!DocumentScannerView.isSupported)

                    Button {
                        showingPhotoPicker = true
                    } label: {
                        Label("Choose a receipt photo", systemImage: "photo")
                    }
                } label: {
                    Label("Add transaction", systemImage: "plus")
                }
            }
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let expense = selectedExpense {
            ExpenseDetailView(expense: expense) {
                editing = expense
            }
        } else {
            ContentUnavailableView("Select a transaction",
                                   systemImage: "list.bullet.rectangle",
                                   description: Text("Choose one from the list to see its details."))
        }
    }

    private var selectableList: some View {
        List(selection: $selectedID) {
            ForEach(viewModel.visibleTransactions) { expense in
                ExpenseRowView(expense: expense)
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

    private func openPendingScan() {
        guard let images = pendingImages, !images.isEmpty else { return }
        pendingImages = nil
        scannedReceipt = ScannedReceipt(images: images)
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        defer { photoSelection = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            viewModel.errorMessage = "That photo couldn't be opened."
            return
        }
        scannedReceipt = ScannedReceipt(images: [image])
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } })
    }
}

#Preview {
    ActivityView(container: .preview())
}
