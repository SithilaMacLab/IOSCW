import Foundation
import Testing
@testable import IosCW

@MainActor
struct AuthValidatorTests {
    @Test("Email addresses are checked after trimming and lowercasing", arguments: [
        ("student@nibm.lk", true),
        ("  Student@NIBM.lk  ", true),
        ("first.last+tag@example.co.uk", true),
        ("not-an-email", false),
        ("a@b", false),
        ("a@b.c", false),
        ("@example.com", false),
        ("", false)
    ])
    func emailValidation(email: String, expected: Bool) {
        #expect(AuthValidator.isValidEmail(email) == expected)
    }

    @Test("Emails are stored trimmed and lowercase")
    func normalisation() {
        #expect(AuthValidator.normalized("  Student@NIBM.lk ") == "student@nibm.lk")
    }

    @Test("Passwords need 8 characters with a letter and a number")
    func passwordRules() {
        #expect(AuthValidator.passwordProblem("short1") == "Use at least 8 characters.")
        #expect(AuthValidator.passwordProblem("onlyletters") == "Include at least one letter and one number.")
        #expect(AuthValidator.passwordProblem("12345678") == "Include at least one letter and one number.")
        #expect(AuthValidator.passwordProblem("abcd1234") == nil)
    }

    @Test("Registration reports the first problem it finds")
    func registration() {
        #expect(AuthValidator.registrationProblem(email: "bad", password: "abcd1234", confirmPassword: "abcd1234")
                == AuthError.invalidEmail.errorDescription)
        #expect(AuthValidator.registrationProblem(email: "a@b.lk", password: "short", confirmPassword: "short")
                == "Use at least 8 characters.")
        #expect(AuthValidator.registrationProblem(email: "a@b.lk", password: "abcd1234", confirmPassword: "abcd12345")
                == "The two passwords don't match.")
        #expect(AuthValidator.registrationProblem(email: "a@b.lk", password: "abcd1234", confirmPassword: "abcd1234") == nil)
    }
}

@MainActor
struct SpendingAreaTests {
    @Test("Areas are grouped by name ignoring case, ranked by total, and income is ignored")
    func ranking() throws {
        let persistence = PersistenceController(inMemory: true)
        let expenses = CoreDataExpenseRepository(persistence: persistence)
        let fort = Place(latitude: 6.93, longitude: 79.84, name: "Fort, Colombo")
        let fortLower = Place(latitude: 6.94, longitude: 79.85, name: "fort, colombo")
        let nugegoda = Place(latitude: 6.86, longitude: 79.89, name: "Nugegoda")

        try expenses.add(ExpenseDraft(amount: 1000, place: fort))
        try expenses.add(ExpenseDraft(amount: 500, place: fortLower))
        try expenses.add(ExpenseDraft(amount: 300, place: nugegoda))
        try expenses.add(ExpenseDraft(type: .income, amount: 9999, place: nugegoda))
        try expenses.add(ExpenseDraft(amount: 200))

        let all = expenses.fetchAll()
        let areas = SpendingAreas.rank(all)

        #expect(areas.map(\.total) == [1500, 300])
        #expect(areas.map(\.count) == [2, 1])
        #expect(areas.first?.name.lowercased() == "fort, colombo")
        #expect(SpendingAreas.unplacedCount(all) == 1)
    }

    @Test("A place with a name is keyed by its lowercase name")
    func namedKey() {
        let result = SpendingAreas.areaKey(for: Place(latitude: 6.9, longitude: 79.8, name: "Fort, Colombo"))
        #expect(result.key == "name:fort, colombo")
        #expect(result.name == "Fort, Colombo")
    }

    @Test("A place without a name falls back to a 1 km grid cell")
    func cellKey() {
        let unnamed = SpendingAreas.areaKey(for: Place(latitude: 6.8895, longitude: 79.8553, name: nil))
        let blank = SpendingAreas.areaKey(for: Place(latitude: 6.8895, longitude: 79.8553, name: "   "))

        #expect(unnamed.key == "cell:6.89,79.86")
        #expect(blank.key == unnamed.key)
        #expect(unnamed.name.hasPrefix("Near"))
    }
}

@MainActor
struct CategorySuggesterTests {
    private let groceries = UUID()
    private let transport = UUID()
    private let food = UUID()

    private var suggester: CategorySuggester {
        CategorySuggester(
            examples: [
                .init(tokens: ["keells", "grocery"], categoryID: groceries, weight: 8),
                .init(tokens: ["pickme", "taxi"], categoryID: transport, weight: 8)
            ],
            merchantMemory: [(key: "cafekumbuk", categoryID: food)])
    }

    @Test("A known brand word picks its category with high confidence")
    func knownWord() throws {
        let suggestion = try #require(suggester.suggest(merchant: "Keells", header: ""))
        #expect(suggestion.categoryID == groceries)
        #expect(suggestion.confidence > 0.9)
    }

    @Test("Words the model has never seen give no suggestion")
    func unknownWords() {
        #expect(suggester.suggest(merchant: "Zzzz Qqqq", header: "") == nil)
    }

    @Test("A merchant the user has used before is remembered")
    func merchantMemory() throws {
        let exact = try #require(suggester.suggest(merchant: "Cafe Kumbuk", header: ""))
        let longer = try #require(suggester.suggest(merchant: "Cafe Kumbuk Colombo 03", header: ""))

        #expect(exact.categoryID == food)
        #expect(exact.confidence == 0.95)
        #expect(longer.categoryID == food)
    }

    @Test("Tokens drop short words, numbers and filler words")
    func tokenising() {
        let tokens = CategorySuggester.tokens(from: "The Keells Store 123 of Colombo")
        #expect(tokens == ["keells"])
    }

    @Test("Names are normalised for comparison")
    func normalising() {
        #expect(CategorySuggester.normalize("Cafe  Kumbuk!") == "cafekumbuk")
    }
}
