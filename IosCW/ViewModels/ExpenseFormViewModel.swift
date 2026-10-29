import Combine
import UIKit

enum RateState: Equatable {
    case notNeeded
    case loading
    case ready(ExchangeRate)
    case unavailable
}

enum LocationState: Equatable {
    case notSet
    case locating
    case located(Place)
    case denied
    case unavailable
}

final class ExpenseFormViewModel: ObservableObject {
    @Published var type: TransactionType = .expense
    @Published var amountText = "" {
        didSet { if amountText != oldValue { flagged.remove(.amount) } }
    }
    @Published var date = Date() {
        didSet { if date != oldValue { flagged.remove(.date) } }
    }
    @Published var merchant = "" {
        didSet { if merchant != oldValue { flagged.remove(.merchant) } }
    }
    @Published var note = ""
    @Published var categoryID: UUID? {
        didSet { if categoryID != oldValue { flagged.remove(.category) } }
    }
    @Published var currencyCode: String {
        didSet { if currencyCode != oldValue { flagged.remove(.currency) } }
    }
    @Published var manualRateText = ""
    @Published private(set) var rateState: RateState
    @Published private(set) var locationState: LocationState = .notSet
    @Published private(set) var flagged: Set<ReviewField> = []
    @Published var errorMessage: String?

    let categories: [ExpenseCategory]
    let currencies: [Currency]
    let receiptThumbnail: UIImage?
    let isReviewingScan: Bool
    private let editing: Expense?
    private let scannedImage: UIImage?
    private let storedImageData: Data?
    private let repository: ExpenseRepositoryProtocol
    private let rates: ExchangeRateServiceProtocol
    private let location: LocationProviding

    init(expenses: ExpenseRepositoryProtocol,
         categories: CategoryRepositoryProtocol,
         rates: ExchangeRateServiceProtocol,
         location: LocationProviding,
         editing: Expense? = nil,
         prefill: ReceiptPrefill? = nil) {
        repository = expenses
        self.rates = rates
        self.location = location
        self.categories = categories.fetchAll()
        self.editing = editing
        isReviewingScan = prefill != nil
        scannedImage = prefill?.thumbnail
        storedImageData = editing?.receiptImageData
        receiptThumbnail = prefill?.thumbnail ?? editing?.receiptImageData.flatMap { UIImage(data: $0) }

        let code = editing?.currencyCode ?? prefill?.currencyCode ?? AppConstants.baseCurrencyCode
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
        } else if code != AppConstants.baseCurrencyCode {
            rateState = .loading
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
            if let place = editing.place {
                locationState = .located(place)
            }
        } else if let prefill {
            merchant = prefill.merchant
            amountText = prefill.amount.map {
                $0.formatted(.number.grouping(.never).precision(.fractionLength(2)))
            } ?? ""
            date = prefill.date
            categoryID = prefill.categoryID
            flagged = prefill.flagged
        }
    }

    var isEditing: Bool { editing != nil }

    var isForeign: Bool { currencyCode != AppConstants.baseCurrencyCode }

    var showsPlaceSection: Bool {
        if !isEditing { return true }
        if case .notSet = locationState { return false }
        return true
    }

    var canAddPlace: Bool { !isEditing }

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

    func captureLocationForScan() async {
        guard isReviewingScan, case .notSet = locationState else { return }
        await captureLocation()
    }

    func captureLocation() async {
        if case .locating = locationState { return }
        locationState = .locating
        switch await location.currentPlace() {
        case .located(let place): locationState = .located(place)
        case .denied: locationState = .denied
        case .unavailable: locationState = .unavailable
        }
    }

    func removeLocation() {
        locationState = .notSet
    }

    func save() -> Bool {
        guard let amount, let exchangeRate, exchangeRate > 0 else {
            errorMessage = ExpenseError.invalidAmount.localizedDescription
            return false
        }

        var place: Place?
        if case .located(let located) = locationState {
            place = located
        }

        let imageData = scannedImage.flatMap { ReceiptImageEncoder.jpegData(from: $0) } ?? storedImageData

        let draft = ExpenseDraft(
            type: type,
            amount: amount,
            currencyCode: currencyCode,
            exchangeRate: exchangeRate,
            date: date,
            merchant: merchant,
            note: note,
            category: categories.first { $0.id == categoryID },
            place: place,
            receiptImageData: imageData
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
