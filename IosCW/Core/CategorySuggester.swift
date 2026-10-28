import Foundation
import NaturalLanguage

struct CategorySuggestion: Equatable {
    let categoryID: UUID
    let confidence: Double
}

struct CategorySuggester {
    struct Example {
        let tokens: [String]
        let categoryID: UUID
        let weight: Double
    }

    static let lexicon: [String: [String]] = [
        "Food & Dining": ["restaurant", "cafe", "coffee", "pizza", "burger", "kfc", "mcdonalds", "dominos",
                          "bakery", "kitchen", "hotel", "bistro", "grill", "diner", "eatery", "pizza hut",
                          "chinese", "biryani", "kottu", "juice", "pub", "bar"],
        "Groceries": ["keells", "cargills", "food city", "arpico", "supermarket", "supercenter", "laugfs",
                      "glomark", "sathosa", "grocery", "mart", "vegetables", "fruits", "market", "fresh"],
        "Transport": ["pickme", "uber", "fuel", "petrol", "diesel", "ceypetco", "ioc", "taxi", "bus", "train",
                      "parking", "toll", "expressway", "garage", "tuk"],
        "Shopping": ["odel", "cotton collection", "daraz", "nolimit", "fashion", "mall", "clothing", "shoes",
                     "boutique", "electronics", "singer", "abans", "softlogic", "crescat", "majestic",
                     "barefoot", "laksala", "kapruka"],
        "Bills & Utilities": ["dialog", "mobitel", "slt", "ceb", "electricity", "water", "airtel", "hutch",
                              "internet", "broadband", "telecom", "postpaid", "prepaid", "reload", "leco",
                              "insurance"],
        "Health": ["pharmacy", "osusala", "healthguard", "hospital", "clinic", "medicine", "medical",
                   "nawaloka", "asiri", "durdans", "dental", "laboratory", "lab", "doctor", "channelling",
                   "hemas"],
        "Entertainment": ["cinema", "scope", "netflix", "spotify", "movie", "theatre", "concert", "ticket",
                          "gaming", "steam", "youtube", "arcade"],
        "Education": ["book", "bookshop", "sarasavi", "vijitha yapa", "tuition", "university", "stationery",
                      "school", "course", "class", "exam", "college", "institute", "godage"],
        "Salary": ["salary", "payroll", "wages"]
    ]

    private static let stopWords: Set<String> = [
        "the", "and", "for", "ltd", "pvt", "limited", "store", "shop", "lanka", "sri", "colombo", "branch",
        "road", "street", "tel", "www", "com", "invoice", "receipt", "thank", "you", "bill", "tax", "vat",
        "total", "cash", "card", "date", "time"
    ]

    private let counts: [UUID: [String: Double]]
    private let totals: [UUID: Double]
    private let categoryIDs: [UUID]
    private let vocabulary: Set<String>
    private let merchantMemory: [(key: String, categoryID: UUID)]

    init(examples: [Example], merchantMemory: [(key: String, categoryID: UUID)] = []) {
        var counts = [UUID: [String: Double]]()
        var totals = [UUID: Double]()
        var vocabulary = Set<String>()

        for example in examples {
            counts[example.categoryID, default: [:]] = counts[example.categoryID] ?? [:]
            for token in example.tokens {
                counts[example.categoryID, default: [:]][token, default: 0] += example.weight
                totals[example.categoryID, default: 0] += example.weight
                vocabulary.insert(token)
            }
        }

        self.counts = counts
        self.totals = totals
        self.categoryIDs = Array(counts.keys)
        self.vocabulary = vocabulary
        self.merchantMemory = merchantMemory
    }

    static func make(categories: [ExpenseCategory], expenses: [Expense]) -> CategorySuggester {
        var examples = [Example]()

        for category in categories {
            examples.append(Example(tokens: tokens(from: category.name), categoryID: category.id, weight: 8))
            for keyword in lexicon[category.name] ?? [] {
                examples.append(Example(tokens: tokens(from: keyword), categoryID: category.id, weight: 8))
            }
        }

        var memory = [(key: String, categoryID: UUID)]()
        var seen = Set<String>()
        for expense in expenses {
            guard let category = expense.category, expense.type == .expense else { continue }
            let text = [expense.merchant, expense.note].joined(separator: " ")
            examples.append(Example(tokens: tokens(from: text), categoryID: category.id, weight: 4))

            let key = normalize(expense.merchant)
            if key.count >= 4, seen.insert(key).inserted {
                memory.append((key: key, categoryID: category.id))
            }
        }

        return CategorySuggester(examples: examples, merchantMemory: memory)
    }

    func suggest(merchant: String, header: String) -> CategorySuggestion? {
        if let remembered = remembered(merchant) {
            return CategorySuggestion(categoryID: remembered, confidence: 0.95)
        }

        let merchantTokens = Self.tokens(from: merchant)
        let features = (merchantTokens + merchantTokens + Self.tokens(from: header)).filter { vocabulary.contains($0) }
        guard !features.isEmpty, !categoryIDs.isEmpty else { return nil }

        let vocabularySize = Double(vocabulary.count)
        let prior = log(1 / Double(categoryIDs.count))

        var scores = [(id: UUID, score: Double)]()
        for id in categoryIDs {
            let tokenCounts = counts[id] ?? [:]
            let total = totals[id] ?? 0
            var score = prior
            for token in features {
                score += log(((tokenCounts[token] ?? 0) + 1) / (total + vocabularySize))
            }
            scores.append((id: id, score: score))
        }

        guard let top = scores.max(by: { $0.score < $1.score }) else { return nil }
        let denominator = scores.reduce(0.0) { $0 + exp($1.score - top.score) }
        let probability = 1 / denominator
        guard probability >= 0.4 else { return nil }
        return CategorySuggestion(categoryID: top.id, confidence: probability)
    }

    static func tokens(from text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        var result = [String]()
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let token = text[range].lowercased()
            if token.count >= 3, token.contains(where: \.isLetter), !stopWords.contains(token) {
                result.append(token)
            }
            return true
        }
        return result
    }

    static func normalize(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func remembered(_ merchant: String) -> UUID? {
        let key = Self.normalize(merchant)
        guard key.count >= 4 else { return nil }

        if let exact = merchantMemory.first(where: { $0.key == key }) {
            return exact.categoryID
        }
        return merchantMemory.first {
            $0.key.count >= 5 && key.count >= 5 && ($0.key.contains(key) || key.contains($0.key))
        }?.categoryID
    }
}
