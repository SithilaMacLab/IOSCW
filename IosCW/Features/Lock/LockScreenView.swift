import SwiftUI

struct LockScreenView: View {
    @EnvironmentObject private var lock: AppLockViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("\(AppConstants.appName) is locked")
                .font(.title2.bold())

            Text("Use \(lock.methodName) to see your finances.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let message = lock.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            Spacer()

            Button {
                Task { await lock.unlock() }
            } label: {
                Label("Unlock with \(lock.methodName)", systemImage: lock.symbolName)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(lock.isAuthenticating)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .task {
            if scenePhase == .active {
                await lock.unlock()
            }
        }
    }
}

struct PrivacyCoverView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text(AppConstants.appName)
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .accessibilityHidden(true)
    }
}

#Preview {
    LockScreenView()
        .environmentObject(AppLockViewModel())
}
