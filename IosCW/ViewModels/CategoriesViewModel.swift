import Combine
import Foundation

final class CategoriesViewModel: ObservableObject {
    @Published private(set) var categories: [ExpenseCategory] = []
    @Published var errorMessage: String?

    private let repository: CategoryRepositoryProtocol
    private var observer: AnyCancellable?

    init(categories: CategoryRepositoryProtocol) {
        repository = categories
        reload()
        observer = observeDataChanges { [weak self] in self?.reload() }
    }

    func reload() {
        categories = repository.fetchAll()
    }

    func save(_ category: ExpenseCategory?, name: String, iconName: String, colorHex: String) -> Bool {
        do {
            if let category {
                try repository.update(category, name: name, iconName: iconName, colorHex: colorHex)
            } else {
                try repository.add(name: name, iconName: iconName, colorHex: colorHex)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete(_ category: ExpenseCategory) {
        do {
            try repository.delete(category)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
