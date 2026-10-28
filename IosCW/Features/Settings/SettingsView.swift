import SwiftUI

struct SettingsView: View {
    let container: AppContainer
    @State private var loadedSamples = false

    var body: some View {
        NavigationStack {
            List {
                Section("Manage") {
                    NavigationLink {
                        CategoriesView(container: container)
                    } label: {
                        Label("Categories", systemImage: "square.grid.2x2")
                    }
                }

                Section("Security") {
                    Text("Face ID lock")
                }

                Section("Data") {
                    Text("Export CSV")
                    Text("Delete account and data")
                }

                #if DEBUG
                Section {
                    Button {
                        SampleData.populate(container)
                        loadedSamples = true
                    } label: {
                        Label("Load sample data", systemImage: "wand.and.stars")
                    }
                    .disabled(loadedSamples)
                } header: {
                    Text("Developer")
                } footer: {
                    Text("Adds 4 months of fake transactions and some budgets so you can see the charts. Debug builds only.")
                }
                #endif
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView(container: .preview(withSamples: false))
}
