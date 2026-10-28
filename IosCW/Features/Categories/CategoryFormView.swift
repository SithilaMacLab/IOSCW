import SwiftUI

struct CategoryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CategoriesViewModel
    let category: ExpenseCategory?

    @State private var name: String
    @State private var iconName: String
    @State private var colorHex: String

    private static let icons = [
        "fork.knife", "cart.fill", "car.fill", "bag.fill", "doc.text.fill", "cross.case.fill",
        "popcorn.fill", "book.fill", "house.fill", "airplane", "gift.fill", "pawprint.fill",
        "gamecontroller.fill", "dumbbell.fill", "cup.and.saucer.fill", "banknote.fill",
        "wifi", "tshirt.fill", "wrench.and.screwdriver.fill", "tag.fill"
    ]

    private static let colors = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#00C7BE", "#30B0C7",
        "#007AFF", "#5856D6", "#AF52DE", "#FF2D55", "#A2845E", "#8E8E93"
    ]

    private let gridColumns = [GridItem(.adaptive(minimum: 52), spacing: 12)]

    init(viewModel: CategoriesViewModel, category: ExpenseCategory?) {
        self.viewModel = viewModel
        self.category = category
        _name = State(initialValue: category?.name ?? "")
        _iconName = State(initialValue: category?.iconName ?? "tag.fill")
        _colorHex = State(initialValue: category?.colorHex ?? "#007AFF")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        CategoryIcon(iconName: iconName, colorHex: colorHex, size: 64)
                        Spacer()
                    }
                    TextField("Name", text: $name)
                }

                Section("Icon") {
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(Self.icons, id: \.self) { icon in
                            Button {
                                iconName = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .background(icon == iconName ? Color(hex: colorHex).opacity(0.25) : Color.clear,
                                                in: Circle())
                                    .overlay(Circle().stroke(icon == iconName ? Color(hex: colorHex) : .clear, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(icon)
                            .accessibilityAddTraits(icon == iconName ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Colour") {
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(Self.colors, id: \.self) { hex in
                            Button {
                                colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if hex == colorHex {
                                            Image(systemName: "checkmark")
                                                .font(.footnote.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Colour \(hex)")
                            .accessibilityAddTraits(hex == colorHex ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(category == nil ? "New category" : "Edit category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if viewModel.save(category, name: name, iconName: iconName, colorHex: colorHex) {
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
