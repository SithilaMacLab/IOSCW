import UIKit

enum ReviewField: Hashable {
    case merchant
    case amount
    case date
    case category
    case currency
}

struct ReceiptPrefill {
    var merchant: String
    var amount: Double?
    var date: Date
    var currencyCode: String
    var categoryID: UUID?
    var flagged: Set<ReviewField>
    var thumbnail: UIImage?
}
