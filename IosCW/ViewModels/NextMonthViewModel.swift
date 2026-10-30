import Combine
import Foundation

final class NextMonthViewModel: ObservableObject {
    @Published private(set) var training: NextMonthTraining

    private let service: NextMonthModelProviding
    private var observer: AnyCancellable?

    init(service: NextMonthModelProviding) {
        self.service = service
        training = service.refresh()
        observer = observeDataChanges { [weak self] in self?.reload() }
    }

    var forecast: NextMonthForecast? {
        if case .ready(let forecast) = training.outcome {
            return forecast
        }
        return nil
    }

    func reload() {
        training = service.refresh()
    }
}
