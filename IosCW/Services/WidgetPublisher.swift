import Combine
import Foundation
import WidgetKit

protocol WidgetPublishing {
    func publish()
}

final class NoWidgetPublisher: WidgetPublishing {
    func publish() {}
}

final class WidgetPublisher: WidgetPublishing {
    private let expenses: ExpenseRepositoryProtocol
    private let budgets: BudgetRepositoryProtocol
    private let auth: AuthServiceProtocol
    private var observer: AnyCancellable?

    init(expenses: ExpenseRepositoryProtocol,
         budgets: BudgetRepositoryProtocol,
         auth: AuthServiceProtocol) {
        self.expenses = expenses
        self.budgets = budgets
        self.auth = auth
        observer = NotificationCenter.default
            .publisher(for: .pocketlensDataDidChange)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.publish() }
    }

    func publish() {
        guard auth.currentUserID != nil else {
            WidgetStore.save(nil)
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetStore.kind)
            return
        }

        let inputs = budgets.fetchAll().compactMap { budget -> WidgetBudgetInput? in
            guard let category = budget.category else { return nil }
            return WidgetBudgetInput(categoryID: category.id.uuidString,
                                     name: category.name,
                                     colorHex: category.colorHex,
                                     limit: budget.monthlyLimit)
        }
        let entries = expenses.fetchAll().map { ForecastEntry($0) }

        WidgetStore.save(WidgetSnapshotBuilder.make(entries: entries, budgets: inputs))
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetStore.kind)
    }
}
