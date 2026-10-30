import SwiftUI

private struct SyncAppearance {
    let title: String
    let headline: String
    let detail: String
    let symbol: String
    let color: Color
    var isBusy = false
}

struct SyncBadgeView: View {
    @ObservedObject var sync: SyncEngine
    @State private var showingDetails = false

    private var appearance: SyncAppearance? {
        switch sync.status {
        case .signedOut:
            nil
        case .notConfigured:
            SyncAppearance(title: "This phone",
                           headline: "Saved on this phone",
                           detail: "Cloud sync is off, so everything is stored on this phone only.",
                           symbol: "iphone",
                           color: .gray)
        case .idle:
            SyncAppearance(title: "Online",
                           headline: "Online",
                           detail: "You are connected. Changes upload automatically.",
                           symbol: "icloud.fill",
                           color: .blue)
        case .syncing:
            SyncAppearance(title: "Syncing",
                           headline: "Syncing",
                           detail: "Sending and receiving your latest changes.",
                           symbol: "arrow.triangle.2.circlepath",
                           color: .blue,
                           isBusy: true)
        case .synced:
            SyncAppearance(title: "Synced",
                           headline: "Up to date",
                           detail: "You are online and everything is backed up.",
                           symbol: "checkmark.icloud.fill",
                           color: .green)
        case .offline:
            SyncAppearance(title: sync.pendingCount > 0 ? "Offline · \(sync.pendingCount)" : "Offline",
                           headline: "Offline",
                           detail: "No internet. Your changes are saved on this phone and upload when you are back online.",
                           symbol: "icloud.slash.fill",
                           color: .orange)
        case .failed(let message):
            SyncAppearance(title: "Problem",
                           headline: "Sync problem",
                           detail: "\(message) It will retry automatically.",
                           symbol: "exclamationmark.icloud.fill",
                           color: .red)
        }
    }

    var body: some View {
        if let appearance {
            Button {
                showingDetails = true
            } label: {
                HStack(spacing: 5) {
                    if appearance.isBusy {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: appearance.symbol)
                            .foregroundStyle(appearance.color)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    Text(appearance.title)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                }
                .animation(.easeInOut(duration: 0.25), value: sync.status)
            }
            .accessibilityLabel("Sync status: \(appearance.headline)")
            .accessibilityHint("Shows details")
            .popover(isPresented: $showingDetails) {
                details(appearance)
                    .presentationCompactAdaptation(.popover)
            }
        }
    }

    private func details(_ appearance: SyncAppearance) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: appearance.symbol)
                    .font(.title2)
                    .foregroundStyle(appearance.color)
                    .accessibilityHidden(true)
                Text(appearance.headline)
                    .font(.headline)
            }

            Text(appearance.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if sync.pendingCount > 0 {
                Label("\(sync.pendingCount) \(sync.pendingCount == 1 ? "change" : "changes") waiting to upload",
                      systemImage: "tray.and.arrow.up")
                    .font(.subheadline)
            }

            if let last = sync.lastSyncedAt {
                Label {
                    Text("Last synced \(last, style: .relative) ago")
                } icon: {
                    Image(systemName: "clock")
                }
                .font(.subheadline)
            }

            if sync.canSync {
                Button {
                    sync.syncNow()
                } label: {
                    Label("Sync now", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(minWidth: 270, maxWidth: 340)
    }
}

extension View {
    func syncStatusBadge(_ sync: SyncEngine) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SyncBadgeView(sync: sync)
            }
        }
    }
}
