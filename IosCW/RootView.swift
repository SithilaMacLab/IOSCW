import SwiftUI

struct RootView: View {
    let container: AppContainer
    @StateObject private var session: AuthViewModel
    @StateObject private var lock = AppLockViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue

    init(container: AppContainer) {
        self.container = container
        _session = StateObject(wrappedValue: AuthViewModel(
            service: container.auth,
            beforeSignIn: { userID in
                container.sync.claimLocalData(for: userID)
            },
            afterSignOut: {
                container.sync.userSignedOut()
                container.widget.publish()
            }))
    }

    private var showsLock: Bool { session.isSignedIn && lock.isLocked }

    private var showsPrivacyCover: Bool {
        session.isSignedIn && lock.isEnabled && !lock.isLocked && scenePhase != .active
    }

    var body: some View {
        ZStack {
            if session.isSignedIn {
                ContentView(container: container)
                    .accessibilityHidden(showsLock)
            } else {
                WelcomeView()
            }

            if showsLock {
                LockScreenView()
                    .transition(.opacity)
            } else if showsPrivacyCover {
                PrivacyCoverView()
            }
        }
        .environmentObject(session)
        .environmentObject(lock)
        .environmentObject(container.sync)
        .animation(.easeInOut(duration: 0.2), value: showsLock)
        .preferredColorScheme(AppearanceMode.resolve(appearanceRaw).colorScheme)
        .task {
            container.sync.sessionChanged()
            container.widget.publish()
            container.predictor.refresh()
            await container.notifications.refresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                lock.lockIfEnabled()
            case .active:
                container.sync.appBecameActive()
                container.widget.publish()
                container.predictor.refresh()
                Task { await container.notifications.refresh() }
                if showsLock {
                    Task { await lock.unlock() }
                }
            default:
                break
            }
        }
        .onChange(of: session.isSignedIn) { _, signedIn in
            lock.releaseLock()
            container.sync.sessionChanged()
            container.widget.publish()
            Task {
                if signedIn {
                    await container.notifications.refresh()
                } else {
                    await container.notifications.reset()
                }
            }
        }
    }
}

#Preview {
    RootView(container: .preview())
}
