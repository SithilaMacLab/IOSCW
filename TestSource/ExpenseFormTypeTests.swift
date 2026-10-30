import Foundation
import Testing
@testable import IosCW

@MainActor
struct ExpenseFormTypeTests {
    private func makeViewModel(type: TransactionType?) throws -> (ExpenseFormViewModel, ExpenseCategory) {
        let persistence = PersistenceController(inMemory: true)
        let categories = CoreDataCategoryRepository(persistence: persistence)
        try categories.seedDefaultsIfNeeded()
        guard let salary = categories.fetchAll().first(where: { $0.name == "Salary" }) else {
            throw TestError()
        }
        let expenses = CoreDataExpenseRepository(persistence: persistence)

        let viewModel: ExpenseFormViewModel
        if let type {
            viewModel = ExpenseFormViewModel(expenses: expenses,
                                             categories: categories,
                                             rates: StaticExchangeRateService(),
                                             location: StaticLocationProvider(),
                                             initialType: type)
        } else {
            viewModel = ExpenseFormViewModel(expenses: expenses,
                                             categories: categories,
                                             rates: StaticExchangeRateService(),
                                             location: StaticLocationProvider())
        }
        return (viewModel, salary)
    }

    @Test("The form opens as an expense by default, with no category chosen")
    func defaultsToExpense() throws {
        let (viewModel, _) = try makeViewModel(type: nil)

        #expect(viewModel.type == .expense)
        #expect(viewModel.categoryID == nil)
    }

    @Test("Add expense opens the form as an expense")
    func expenseButton() throws {
        let (viewModel, _) = try makeViewModel(type: .expense)

        #expect(viewModel.type == .expense)
        #expect(viewModel.categoryID == nil)
    }

    @Test("Add income opens the form as income with the Salary category chosen")
    func incomeButton() throws {
        let (viewModel, salary) = try makeViewModel(type: .income)

        #expect(viewModel.type == .income)
        #expect(viewModel.categoryID == salary.id)
    }
}
