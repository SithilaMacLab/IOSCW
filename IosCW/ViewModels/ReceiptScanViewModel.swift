import Combine
import UIKit

final class ReceiptScanViewModel: ObservableObject {
    enum Phase {
        case reading
        case ready(ReceiptPrefill)
        case manual
        case failed(String)
    }

    @Published private(set) var phase: Phase = .reading

    private let images: [UIImage]
    private let recognizer: TextRecognizing
    private let expenseRepository: ExpenseRepositoryProtocol
    private let categoryRepository: CategoryRepositoryProtocol
    private var started = false

    init(images: [UIImage],
         recognizer: TextRecognizing,
         expenses: ExpenseRepositoryProtocol,
         categories: CategoryRepositoryProtocol) {
        self.images = images
        self.recognizer = recognizer
        expenseRepository = expenses
        categoryRepository = categories
    }

    func start() async {
        guard !started else { return }
        started = true

        var rows = [ReceiptRow]()
        do {
            for image in images {
                let lines = try await recognizer.recognize(image)
                rows += ReceiptLayout.rows(from: lines)
            }
        } catch {
            phase = .failed("This image couldn't be read. Try taking the photo again.")
            return
        }

        guard !rows.isEmpty else {
            phase = .failed("No text was found. Try again in good light with the whole receipt in view.")
            return
        }

        let parsed = ReceiptParser.parse(rows: rows)
        let suggester = CategorySuggester.make(categories: categoryRepository.fetchAll(),
                                               expenses: expenseRepository.fetchAll())
        let suggestion = suggester.suggest(merchant: parsed.merchant.value ?? "", header: parsed.headerText)
        phase = .ready(makePrefill(from: parsed, suggestion: suggestion))
    }

    func enterManually() {
        phase = .manual
    }

    private func makePrefill(from parsed: ParsedReceipt, suggestion: CategorySuggestion?) -> ReceiptPrefill {
        var flagged = Set<ReviewField>()

        if !parsed.merchant.isReliable() { flagged.insert(.merchant) }
        if !parsed.total.isReliable() { flagged.insert(.amount) }
        if !parsed.date.isReliable() { flagged.insert(.date) }
        if !parsed.currencyCode.isReliable() { flagged.insert(.currency) }

        if (suggestion?.confidence ?? 0) < ParsedReceipt.reliableThreshold {
            flagged.insert(.category)
        }

        return ReceiptPrefill(
            merchant: parsed.merchant.value ?? "",
            amount: parsed.total.value,
            date: parsed.date.value ?? Date(),
            currencyCode: parsed.currencyCode.value ?? AppConstants.baseCurrencyCode,
            categoryID: suggestion?.categoryID,
            flagged: flagged,
            thumbnail: images.first)
    }
}
