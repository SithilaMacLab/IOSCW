import Combine
import Foundation

final class AppLockViewModel: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var isLocked: Bool
    @Published private(set) var isAuthenticating = false
    @Published var errorMessage: String?

    private let authenticator: BiometricAuthenticating
    private let defaults: UserDefaults
    static let enabledKey = "appLockEnabled"

    init(authenticator: BiometricAuthenticating = LocalBiometricAuthenticator(),
         defaults: UserDefaults = .standard) {
        self.authenticator = authenticator
        self.defaults = defaults
        let enabled = defaults.bool(forKey: Self.enabledKey)
        isEnabled = enabled
        isLocked = enabled
    }

    var methodName: String { authenticator.methodName }
    var symbolName: String { authenticator.symbolName }

    func lockIfEnabled() {
        if isEnabled {
            isLocked = true
        }
    }

    func resetAfterAccountDeletion() {
        persist(false)
        isLocked = false
        errorMessage = nil
    }

    func releaseLock() {
        isLocked = false
        errorMessage = nil
    }

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        let result = await authenticator.authenticate(reason: "Unlock Pocketlens")
        switch result {
        case .success:
            isLocked = false
            errorMessage = nil
        case .cancelled:
            errorMessage = nil
        case .failed(let message):
            errorMessage = message
        case .unavailable:
            persist(false)
            isLocked = false
            errorMessage = nil
        }
    }

    func setEnabled(_ enable: Bool) async {
        guard enable != isEnabled, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        let reason = enable ? "Turn on the app lock" : "Turn off the app lock"
        let result = await authenticator.authenticate(reason: reason)
        switch result {
        case .success:
            persist(enable)
            errorMessage = nil
        case .cancelled:
            errorMessage = nil
        case .failed(let message):
            errorMessage = message
        case .unavailable:
            errorMessage = "Set up Face ID or a device passcode in the iOS Settings app first."
        }
    }

    private func persist(_ value: Bool) {
        isEnabled = value
        defaults.set(value, forKey: Self.enabledKey)
    }
}
