import CoreLocation

struct Place: Equatable {
    let latitude: Double
    let longitude: Double
    let name: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
