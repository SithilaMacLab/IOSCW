import SwiftUI

struct SyncBannerView: View {
    @EnvironmentObject private var sync: SyncEngine
    @State private var showSynced = false

    private var content: (text: String, symbol: String, color: Color)? {
        switch sync.status {
        case .offline:
            let waiting = sync.pendingCount
            let text = waiting > 0
                ? "Offline · \(waiting) \(waiting == 1 ? "change" : "changes") waiting"
                : "Offline · everything is saved on this phone"
            return (text, "wifi.slash", .orange)
        case .syncing:
            return ("Syncing…", "arrow.triangle.2.circlepath", .blue)
        case .failed:
            return ("Sync problem · will retry", "exclamationmark.triangle.fill", .red)
        case .synced where showSynced:
            return ("Synced", "checkmark.circle.fill", .green)
        default:
            return nil
        }
    }

    var body: some View {
        Group {
            if let content {
                Label(content.text, systemImage: content.symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(content.color)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.bar)
                    .accessibilityElement(children: .combine)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: sync.status)
        .onChange(of: sync.status) { _, newStatus in
            if case .synced = newStatus {
                showSynced = true
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    showSynced = false
                }
            } else {
                showSynced = false
            }
        }
    }
}
