import SwiftUI

@main
struct IosCWApp: App {
    private let container = AppContainer.live

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
        }
    }
}
