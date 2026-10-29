import CoreLocation
import Foundation

struct AreaTotal: Identifiable, Equatable {
    let id: String
    let name: String
    let total: Double
    let count: Int
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum SpendingAreas {
    private struct Bucket {
        var name: String
        var total = 0.0
        var count = 0
        var latitudeSum = 0.0
        var longitudeSum = 0.0
    }

    static func rank(_ expenses: [Expense], since: Date? = nil) -> [AreaTotal] {
        var buckets = [String: Bucket]()

        for expense in expenses where expense.type == .expense {
            guard let place = expense.place else { continue }
            if let since, expense.date < since { continue }

            let (key, name) = areaKey(for: place)
            var bucket = buckets[key] ?? Bucket(name: name)
            bucket.total += expense.amountLKR
            bucket.count += 1
            bucket.latitudeSum += place.latitude
            bucket.longitudeSum += place.longitude
            buckets[key] = bucket
        }

        return buckets
            .map { key, bucket in
                AreaTotal(id: key,
                          name: bucket.name,
                          total: bucket.total,
                          count: bucket.count,
                          latitude: bucket.latitudeSum / Double(bucket.count),
                          longitude: bucket.longitudeSum / Double(bucket.count))
            }
            .sorted { $0.total > $1.total }
    }

    static func unplacedCount(_ expenses: [Expense], since: Date? = nil) -> Int {
        expenses.filter { expense in
            guard expense.type == .expense, expense.place == nil else { return false }
            if let since { return expense.date >= since }
            return true
        }.count
    }

    static func areaKey(for place: Place) -> (key: String, name: String) {
        if let name = place.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return ("name:" + name.lowercased(), name)
        }
        let latitude = (place.latitude * 100).rounded() / 100
        let longitude = (place.longitude * 100).rounded() / 100
        let label = "Near \(latitude.formatted(.number.precision(.fractionLength(2)))), \(longitude.formatted(.number.precision(.fractionLength(2))))"
        return ("cell:\(latitude),\(longitude)", label)
    }
}
