import CoreGraphics
import Foundation
import Testing
@testable import IosCW

@MainActor
struct ReceiptParserTests {
    private let now = TestClock.date(2026, 10, 29)
    private let calendar = TestClock.calendar

    private func rows(_ texts: String...) -> [ReceiptRow] {
        texts.map { ReceiptRow(text: $0, confidence: 1) }
    }

    @Test("Merchant is the first name-like row, turned into Title Case")
    func merchantFromFirstRow() {
        let merchant = ReceiptParser.merchant(in: rows("KEELLS SUPER", "Tel 0112345678", "TOTAL 1,250.00"))
        #expect(merchant.value == "Keells Super")
        #expect(isClose(merchant.confidence, 1.0))
    }

    @Test("Merchant skips phone, invoice and web address rows")
    func merchantSkipsNoise() {
        let merchant = ReceiptParser.merchant(in: rows("Tel 0112345678", "Invoice 00123", "www.shop.lk", "Cafe Kumbuk"))
        #expect(merchant.value == "Cafe Kumbuk")
        #expect(merchant.confidence < 1.0)
    }

    @Test("No merchant when nothing looks like a name")
    func merchantMissing() {
        let merchant = ReceiptParser.merchant(in: rows("0112345678", "12/10/2026", "1,250.00"))
        #expect(merchant.value == nil)
        #expect(!merchant.isReliable())
    }

    @Test("A grand total row beats subtotals and cash rows")
    func grandTotalWins() {
        let total = ReceiptParser.total(in: rows("Keells Super", "Item A 100.00", "Sub Total 1,000.00",
                                                 "Grand Total 1,250.00", "Cash 2,000.00"))
        #expect(total.value == 1250)
        #expect(isClose(total.confidence, 1.0))
    }

    @Test("A plain total row is used with slightly lower confidence")
    func plainTotal() {
        let total = ReceiptParser.total(in: rows("Cafe Kumbuk", "Latte 300.00", "Cake 150.00",
                                                 "TOTAL 450.00", "CASH 500.00", "CHANGE 50.00"))
        #expect(total.value == 450)
        #expect(isClose(total.confidence, 0.95))
    }

    @Test("The amount on the row below a lone Total label is used")
    func totalOnNextRow() {
        let total = ReceiptParser.total(in: rows("Pizza Hut", "Total", "1,980.00"))
        #expect(total.value == 1980)
    }

    @Test("Without a total keyword the largest amount is used and flagged")
    func largestAmountFallback() {
        let total = ReceiptParser.total(in: rows("Dialog Axiata", "Reload 1,000.00", "Thank you"))
        #expect(total.value == 1000)
        #expect(!total.isReliable())
    }

    @Test("No amounts means no total")
    func noTotal() {
        let total = ReceiptParser.total(in: rows("Thank you", "Come again"))
        #expect(total.value == nil)
    }

    @Test("Amount formats are understood", arguments: [
        ("1,250.00", 1250.0),
        ("1.250,00", 1250.0),
        ("12,50", 12.5),
        ("1,250", 1250.0),
        ("99.95", 99.95)
    ])
    func amountFormats(text: String, expected: Double) {
        #expect(ReceiptParser.parseAmount(text) == expected)
    }

    @Test("Zero is not an amount")
    func zeroAmount() {
        #expect(ReceiptParser.parseAmount("0.00") == nil)
    }

    @Test("Every amount on a row is found")
    func extractsAllAmounts() {
        #expect(ReceiptParser.extractAmounts(in: "Milk 2 x 160.00 = 320.00") == [160, 320])
    }

    @Test("Dates are read day first, like Sri Lankan receipts")
    func dayFirstDate() {
        let date = ReceiptParser.date(in: rows("Date: 05/10/2026"), now: now, calendar: calendar)
        #expect(date.value == TestClock.date(2026, 10, 5))
        #expect(isClose(date.confidence, 1.0))
    }

    @Test("A number above 12 decides which part is the day")
    func dayDecidedByRange() {
        let first = ReceiptParser.date(in: rows("13/10/2026"), now: now, calendar: calendar)
        let second = ReceiptParser.date(in: rows("10/13/2026"), now: now, calendar: calendar)
        #expect(first.value == TestClock.date(2026, 10, 13))
        #expect(second.value == TestClock.date(2026, 10, 13))
    }

    @Test("Year-first and month-name dates are read")
    func otherDateFormats() {
        let iso = ReceiptParser.date(in: rows("2026-10-05"), now: now, calendar: calendar)
        let dayName = ReceiptParser.date(in: rows("5 Oct 2026"), now: now, calendar: calendar)
        let monthName = ReceiptParser.date(in: rows("Oct 5, 2026"), now: now, calendar: calendar)
        #expect(iso.value == TestClock.date(2026, 10, 5))
        #expect(dayName.value == TestClock.date(2026, 10, 5))
        #expect(monthName.value == TestClock.date(2026, 10, 5))
    }

    @Test("Dates far in the future, impossible dates and expiry dates are rejected")
    func invalidDates() {
        let future = ReceiptParser.date(in: rows("Date 01/12/2027"), now: now, calendar: calendar)
        let impossible = ReceiptParser.date(in: rows("31/02/2026"), now: now, calendar: calendar)
        let expiry = ReceiptParser.date(in: rows("Exp 05/10/2026"), now: now, calendar: calendar)
        let old = ReceiptParser.date(in: rows("05/10/2015"), now: now, calendar: calendar)
        #expect(future.value == nil)
        #expect(impossible.value == nil)
        #expect(expiry.value == nil)
        #expect(old.value == nil)
    }

    @Test("Currency is found from codes and symbols, defaulting to LKR")
    func currencyDetection() {
        let rupees = ReceiptParser.currency(in: rows("Total Rs 1,250.00"))
        let dollars = ReceiptParser.currency(in: rows("Total USD 12.50"))
        let symbol = ReceiptParser.currency(in: rows("Total $12.50"))
        let none = ReceiptParser.currency(in: rows("Hello"))

        #expect(rupees.value == "LKR")
        #expect(isClose(rupees.confidence, 0.9))
        #expect(dollars.value == "USD")
        #expect(isClose(dollars.confidence, 0.9))
        #expect(symbol.value == "USD")
        #expect(isClose(symbol.confidence, 0.55))
        #expect(none.value == "LKR")
        #expect(isClose(none.confidence, 0.7))
    }

    @Test("A whole receipt is parsed into all four fields")
    func wholeReceipt() {
        let parsed = ReceiptParser.parse(
            rows: rows("KEELLS SUPER", "Date: 05/10/2026", "Milk 320.00", "TOTAL Rs 1,250.00"),
            now: now,
            calendar: calendar)

        #expect(parsed.merchant.value == "Keells Super")
        #expect(parsed.date.value == TestClock.date(2026, 10, 5))
        #expect(parsed.total.value == 1250)
        #expect(parsed.currencyCode.value == "LKR")
        #expect(parsed.headerText.contains("KEELLS SUPER"))
    }

    @Test("Low OCR confidence lowers the field confidence")
    func ocrConfidenceMatters() {
        let sharp = ReceiptParser.total(in: [ReceiptRow(text: "TOTAL 450.00", confidence: 1.0)])
        let blurry = ReceiptParser.total(in: [ReceiptRow(text: "TOTAL 450.00", confidence: 0.0)])
        #expect(sharp.confidence > blurry.confidence)
        #expect(isClose(blurry.confidence, 0.6 * 0.95))
    }
}

@MainActor
struct ReceiptLayoutTests {
    @Test("Pieces on the same line are joined left to right, lines run top to bottom")
    func groupsPiecesIntoRows() {
        let lines = [
            RecognizedLine(text: "1,250.00", confidence: 1.0, box: CGRect(x: 0.7, y: 0.51, width: 0.2, height: 0.05)),
            RecognizedLine(text: "SHOP", confidence: 1.0, box: CGRect(x: 0.1, y: 0.9, width: 0.3, height: 0.05)),
            RecognizedLine(text: "TOTAL", confidence: 0.5, box: CGRect(x: 0.1, y: 0.5, width: 0.2, height: 0.05))
        ]

        let rows = ReceiptLayout.rows(from: lines)

        #expect(rows.map(\.text) == ["SHOP", "TOTAL  1,250.00"])
        #expect(rows[1].confidence == 0.5)
    }

    @Test("No lines means no rows")
    func emptyInput() {
        #expect(ReceiptLayout.rows(from: []).isEmpty)
    }
}
