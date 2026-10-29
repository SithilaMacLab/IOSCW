import CoreLocation

enum LocationOutcome: Equatable {
    case located(Place)
    case denied
    case unavailable
}

protocol LocationProviding {
    func currentPlace() async -> LocationOutcome
}

final class DeviceLocationProvider: NSObject, LocationProviding, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Void, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
    private var requestCounter = 0

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func currentPlace() async -> LocationOutcome {
        if manager.authorizationStatus == .notDetermined {
            await requestAuthorization()
        }

        switch manager.authorizationStatus {
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .unavailable
        default:
            break
        }

        guard let location = await requestLocation() else { return .unavailable }
        let name = await areaName(for: location)
        return .located(Place(latitude: location.coordinate.latitude,
                              longitude: location.coordinate.longitude,
                              name: name))
    }

    private func requestAuthorization() async {
        await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    private func requestLocation() async -> CLLocation? {
        requestCounter += 1
        let token = requestCounter

        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()

            Task { [weak self] in
                try? await Task.sleep(for: .seconds(10))
                guard let self, self.requestCounter == token else { return }
                self.finishLocation(nil)
            }
        }
    }

    private func finishLocation(_ location: CLLocation?) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        continuation.resume(returning: location)
    }

    private func authorizationChanged() {
        guard manager.authorizationStatus != .notDetermined,
              let continuation = authorizationContinuation else { return }
        authorizationContinuation = nil
        continuation.resume()
    }

    private func areaName(for location: CLLocation) async -> String? {
        let geocoder = CLGeocoder()
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else { return nil }

        let parts = [placemark.subLocality, placemark.locality].compactMap { $0 }.filter { !$0.isEmpty }
        if !parts.isEmpty {
            return parts.joined(separator: ", ")
        }
        return placemark.name
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latest = locations.last
        Task { @MainActor [weak self] in
            self?.finishLocation(latest)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.finishLocation(nil)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            self?.authorizationChanged()
        }
    }
}

struct StaticLocationProvider: LocationProviding {
    var outcome: LocationOutcome = .unavailable

    func currentPlace() async -> LocationOutcome {
        outcome
    }
}
