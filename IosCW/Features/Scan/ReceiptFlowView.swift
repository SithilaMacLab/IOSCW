import SwiftUI

struct ScannedReceipt: Identifiable {
    let id = UUID()
    let images: [UIImage]
}

struct ReceiptFlowView: View {
    @Environment(\.dismiss) private var dismiss
    let container: AppContainer
    @StateObject private var viewModel: ReceiptScanViewModel

    init(container: AppContainer, images: [UIImage]) {
        self.container = container
        _viewModel = StateObject(wrappedValue: ReceiptScanViewModel(
            images: images,
            recognizer: container.recognizer,
            expenses: container.expenses,
            categories: container.categories))
    }

    var body: some View {
        Group {
            switch viewModel.phase {
            case .reading:
                readingView

            case .ready(let prefill):
                ExpenseFormView(container: container, prefill: prefill)

            case .manual:
                ExpenseFormView(container: container)

            case .failed(let message):
                failedView(message)
            }
        }
        .task { await viewModel.start() }
    }

    private var readingView: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                Text("Reading your receipt…")
                    .font(.headline)
                Text("This happens on your phone. The photo is never uploaded.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func failedView(_ message: String) -> some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Couldn't read the receipt", systemImage: "doc.text.magnifyingglass")
            } description: {
                Text(message)
            } actions: {
                Button("Enter it manually") { viewModel.enterManually() }
                    .buttonStyle(.borderedProminent)
                Button("Close") { dismiss() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
