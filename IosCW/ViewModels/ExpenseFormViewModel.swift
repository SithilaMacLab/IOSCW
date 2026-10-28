import Combine
import Foundation

enum RateState: Equatable {
    case notNeeded
    case loading
    case ready(ExchangeRate)
    case unavailable
}

final class ExpenseFormViewModel: ObservableObject {
    @Published var type: TransactionType = .expense
    @Published var amountText = ""
    @Published var date = Date()
    @Published var merchant = ""
    @Published var note = ""
    @Published var categoryID: UUID?
    @Published var currencyCode: String
    @Published var manualRateText = ""
    @Published private(set) var rateState: RateState
    @Published var errorMessage: String?

    let categories: [ExpenseCategory]
    let currencies: [Currency]
    private let editing: Expense?
    private let repository: ExpenseRepositoryProtocol
    private let rates: ExchangeRateServiceProtocol

    init(expenses: ExpenseRepositoryProtocol,
         categories: CategoryRepositoryProtocol,
         rates: ExchangeRateServiceProtocol,
         editing: Expense? = nil) {
        repository = expenses
        self.rates = rates
        self.categories = categories.fetchAll()
        self.editing = editing

        let code = editing?.currencyCode ?? AppConstants.baseCurrencyCode
        currencyCode = code

        var list = Currency.supported
        if !list.contains(where: { $0.code == code }) {
            list.append(Currency(code: code))
        }
        currencies = list

        if let editing, code != AppConstants.baseCurrencyCode {
            rateState = .ready(ExchangeRate(currencyCode: code,
                                            rateToLKR: editing.exchangeRate,
                                            asOf: editing.date,
                                            source: .stored))
        } else {
            rateState = .notNeeded
        }

        if let editing {
            type = editing.type
            amountText = editing.amount.formatted(.number.grouping(.never).precision(.fractionLength(0...2)))
            date = editing.date
            merchant = editing.merchant
            note = editing.note
            categoryID = editing.category?.id
        }
    }

    var isEditing: Bool { editing != nil }

    var isForeign: Bool { currencyCode != AppConstants.baseCurrencyCode }

    var amount: Double? {
        Self.parse(amountText)
    }

    var exchangeRate: Double? {
        switch rateState {
        case .notNeeded: 1
        case .ready(let rate): rate.rateToLKR
        case .unavailable: Self.parse(manualRateText)
        case .loading: nil
        }
    }

    var convertedLKR: Double? {
        guard let amount, let exchangeRate else { return nil }
        return amount * exchangeRate
    }

    var canSave: Bool {
        (amount ?? 0) > 0 && (exchangeRate ?? 0) > 0
    }

    func currencyDidChange() async {
        guard isForeign else {
            rateState = .notNeeded
            return
        }
        if case .ready(let current) = rateState,
           current.currencyCode == currencyCode,
           current.source == .stored {
            return
        }

        let code = currencyCode
        rateState = .loading
        do {
            let rate = try await rates.rate(for: code)
            guard code == currencyCode else { return }
            rateState = .ready(rate)
        } catch {
            guard code == currencyCode else { return }
            rateState = .unavailable
        }
    }

    func save() -> Bool {
        guard let amount, let exchangeRate, exchangeRate > 0 else {
            errorMessage = ExpenseError.invalidAmount.localizedDescription
            return false
        }

        let draft = ExpenseDraft(
            type: type,
            amount: amount,
            currencyCode: currencyCode,
            exchangeRate: exchangeRate,
            date: date,
            merchant: merchant,
            note: note,
            category: categories.first { $0.id == categoryID }
        )

        do {
            if let editing {
                try repository.update(editing, with: draft)
            } else {
                try repository.add(draft)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private static func parse(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
    }
}
