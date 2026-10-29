import Foundation
import Testing
@testable import IosCW

@MainActor
struct CSVExporterTests {
    private let calendar = TestClock.calendar

    private func row(merchant: String = "Cafe Kumbuk",
                     note: String = "",
                     place: String = "") -> CSVRow {
        CSVRow(date: TestClock.date(2026, 10, 5),
               type: "Expense",
               merchant: merchant,
               category: "Food & Dining",
               amount: 1250,
               currencyCode: "LKR",
               exchangeRate: 1,
               amountLKR: 1250,
               note: note,
               place: place)
    }

    @Test("An empty export still has the header row")
    func headerOnly() {
        let text = CSVExporter.make([], calendar: calendar)
        #expect(text == "Date,Type,Merchant,Category,Amount,Currency,Exchange rate to LKR,Amount (LKR),Note,Place\r\n")
    }

    @Test("A row is written with ISO dates and fixed decimals")
    func singleRow() {
        let text = CSVExporter.make([row(place: "Bambalapitiya, Colombo")], calendar: calendar)
        let lines = text.components(separatedBy: "\r\n")

        #expect(lines.count == 3)
        #expect(lines[1] == "2026-10-05,Expense,Cafe Kumbuk,Food & Dining,1250.00,LKR,1.000000,1250.00,,\"Bambalapitiya, Colombo\"")
        #expect(lines[2].isEmpty)
    }

    @Test("A foreign currency row keeps the original amount and the rate")
    func foreignCurrency() {
        let foreign = CSVRow(date: TestClock.date(2026, 10, 5),
                             type: "Expense",
                             merchant: "Amazon",
                             category: "Shopping",
                             amount: 12.5,
                             currencyCode: "USD",
                             exchangeRate: 300,
                             amountLKR: 3750,
                             note: "",
                             place: "")

        let text = CSVExporter.make([foreign], calendar: calendar)

        #expect(text.contains("12.50,USD,300.000000,3750.00"))
    }

    @Test("Fields with commas, quotes and line breaks are quoted", arguments: [
        ("plain", "plain"),
        ("a,b", "\"a,b\""),
        ("say \"hi\"", "\"say \"\"hi\"\"\""),
        ("line1\nline2", "\"line1\nline2\""),
        ("line1\r\nline2", "\"line1\r\nline2\""),
        ("", "")
    ])
    func quoting(input: String, expected: String) {
        #expect(CSVExporter.escape(input) == expected)
    }

    @Test("Text that a spreadsheet would run as a formula is neutralised", arguments: [
        ("=SUM(A1)", "'=SUM(A1)"),
        ("+94 77", "'+94 77"),
        ("-5", "'-5"),
        ("@cmd", "'@cmd"),
        ("=A,B", "\"'=A,B\"")
    ])
    func formulaGuard(input: String, expected: String) {
        #expect(CSVExporter.escape(input) == expected)
    }

    @Test("Rows keep their order")
    func rowOrder() {
        let text = CSVExporter.make([row(merchant: "First"), row(merchant: "Second")], calendar: calendar)
        let first = text.range(of: "First")
        let second = text.range(of: "Second")

        #expect(first != nil && second != nil)
        #expect(first!.lowerBound < second!.lowerBound)
    }

    @Test("The file name carries the date")
    func fileName() {
        #expect(CSVExporter.fileName(now: TestClock.date(2026, 10, 29), calendar: calendar)
                == "Pocketlens-transactions-2026-10-29.csv")
    }

    @Test("A saved transaction becomes a row with its category, note and place")
    func fromExpense() throws {
        let persistence = PersistenceController(inMemory: true)
        let categories = CoreDataCategoryRepository(persistence: persistence)
        let expenses = CoreDataExpenseRepository(persistence: persistence)
        try categories.seedDefaultsIfNeeded()
        let groceries = try #require(categories.fetchAll().first { $0.name == "Groceries" })

        try expenses.add(ExpenseDraft(
            amount: 800,
            date: TestClock.date(2026, 10, 5),
            merchant: "=Keells",
            note: "milk, eggs",
            category: groceries,
            place: Place(latitude: 6.93, longitude: 79.84, name: "Fort, Colombo")))

        let saved = try #require(expenses.fetchAll().first)
        let csv = CSVExporter.make([CSVRow(saved)], calendar: calendar)

        #expect(csv.contains("'=Keells"))
        #expect(csv.contains("Groceries"))
        #expect(csv.contains("\"milk, eggs\""))
        #expect(csv.contains("\"Fort, Colombo\""))
        #expect(csv.contains("800.00"))
    }
}
