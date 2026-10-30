import SwiftUI
import UserNotifications

@main
struct IosCWApp: App {
    private let container = AppContainer.live

    init() {
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
