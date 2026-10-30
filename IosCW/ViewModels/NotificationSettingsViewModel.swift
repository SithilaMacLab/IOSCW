import Combine
import Foundation

final class NotificationSettingsViewModel: ObservableObject {
    @Published private(set) var settings: NotificationSettings
    @Published private(set) var permission: NotificationPermission = .notDetermined
    @Published var message: String?

    private let manager: NotificationManaging

    init(manager: NotificationManaging) {
        self.manager = manager
        settings = manager.settings()
    }

    var isDenied: Bool { permission == .denied }

    func load() async {
        permission = await manager.permission()
        settings = manager.settings()
        if permission != .denied {
            message = nil
        }
    }

    func setOn(_ on: Bool) async {
        if on {
            permission = await manager.turnOn()
            settings = manager.settings()
            message = permission == .allowed
                ? nil
                : "Notifications are switched off for Pocketlens in the iOS Settings app."
        } else {
            var updated = settings
            updated.isOn = false
            await update(updated)
        }
    }

    func update(_ updated: NotificationSettings) async {
        settings = updated
        await manager.save(updated)
    }

    func sendTest() async {
        await manager.sendTest()
    }
}
