import SwiftUI

struct CategoriesView: View {
    @StateObject private var viewModel: CategoriesViewModel
    @State private var showingAdd = false
    @State private var editing: ExpenseCategory?

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: CategoriesViewModel(categories: container.categories))
    }

    var body: some View {
        List {
            ForEach(viewModel.categories) { category in
                Button {
                    editing = category
                } label: {
                    HStack(spacing: 12) {
                        CategoryIcon(iconName: category.iconName, colorHex: category.colorHex)
                        Text(category.name)
                        Spacer()
                        if category.isDefault {
                            Text("Default")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: !category.isDefault) {
                    if !category.isDefault {
                        Button(role: .destructive) {
                            viewModel.delete(category)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add category", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            CategoryFormView(viewModel: viewModel, category: nil)
        }
        .sheet(item: $editing) { category in
            CategoryFormView(viewModel: viewModel, category: category)
        }
        .alert("Something went wrong", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } })
    }
}

#Preview {
    NavigationStack {
        CategoriesView(container: .preview())
    }
}
