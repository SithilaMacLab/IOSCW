import Foundation

enum CurrencyFormatter {
    static func lkr(_ value: Double) -> String {
        value.formatted(.currency(code: AppConstants.baseCurrencyCode))
    }

    static func compact(_ value: Double) -> String {
        value.formatted(.number.notation(.compactName))
    }
}
