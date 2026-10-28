import Combine
import Foundation

func observeDataChanges(_ handler: @escaping () -> Void) -> AnyCancellable {
    NotificationCenter.default
        .publisher(for: .pocketlensDataDidChange)
        .receive(on: DispatchQueue.main)
        .sink { _ in handler() }
}
