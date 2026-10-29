import Foundation

enum BudgetStatus {
    case onTrack
    case nearLimit
    case overBudget

    init(progress: Double) {
        switch progress {
        case ..<0.8: self = .onTrack
        case ..<1.0: self = .nearLimit
        default: self = .overBudget
        }
    }

    var title: String {
        switch self {
        case .onTrack: "On track"
        case .nearLimit: "Near limit"
        case .overBudget: "Over budget"
        }
    }

    var systemImage: String {
        switch self {
        case .onTrack: "checkmark.circle.fill"
        case .nearLimit: "exclamationmark.triangle.fill"
        case .overBudget: "exclamationmark.octagon.fill"
        }
    }
}
