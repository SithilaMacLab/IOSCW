import Foundation
import Testing
@testable import IosCW

@MainActor
struct NextMonthServiceTests {
    @MainActor
    private struct Fixture {
        let expenses: CoreDataExpenseRepository
        let store: NextMonthModelStore
        let clock: ClockBox
        let service: NextMonthModelService

        init(start: Date? = nil) {
            let persistence = PersistenceController(inMemory: true)
            let expenses = CoreDataExpenseRepository(persistence: persistence)
            let store = NextMonthModelStore(defaults: isolatedDefaults())
            let clock = ClockBox(start ?? TestClock.date(2026, 11, 15))

            self.expenses = expenses
            self.store = store
            self.clock = clock
            self.service = NextMonthModelService(expenses: expenses,
                                                 store: store,
                                                 calendar: TestClock.calendar,
                                                 now: { clock.date })
        }

        func addHistory() throws {
            try expenses.add(ExpenseDraft(amount: 100, date: TestClock.date(2026, 8, 10)))
            try expenses.add(ExpenseDraft(amount: 200, date: TestClock.date(2026, 9, 10)))
            try expenses.add(ExpenseDraft(amount: 300, date: TestClock.date(2026, 10, 10)))
        }
    }

    @Test("The first refresh trains the model and saves it")
    func firstRefreshTrains() throws {
        let fixture = Fixture()
        try fixture.addHistory()

        let training = fixture.service.refresh()

        #expect(training.retrained)
        #expect(training.trainedAt == TestClock.date(2026, 11, 15))
        guard case .ready(let forecast) = training.outcome else {
            Issue.record("expected a forecast")
            return
        }
        #expect(forecast.monthsOfHistory == 3)
        #expect(fixture.store.load()?.forecast == forecast)
    }

    @Test("Opening the app again in the same month reuses the saved model")
    func savedModelIsReused() throws {
        let fixture = Fixture()
        try fixture.addHistory()
        let first = fixture.service.refresh()

        try fixture.expenses.add(ExpenseDraft(amount: 999, date: TestClock.date(2026, 11, 10)))
        let second = fixture.service.refresh()

        #expect(!second.retrained)
        #expect(second.outcome == first.outcome)
        #expect(second.trainedAt == first.trainedAt)
    }

    @Test("A new month retrains the model with the month that just finished")
    func newMonthRetrains() throws {
        let fixture = Fixture()
        try fixture.addHistory()
        try fixture.expenses.add(ExpenseDraft(amount: 400, date: TestClock.date(2026, 11, 10)))
        let november = fixture.service.refresh()

        fixture.clock.date = TestClock.date(2026, 12, 15)
        let december = fixture.service.refresh()

        #expect(december.retrained)
        #expect(december.outcome != november.outcome)
        guard case .ready(let forecast) = december.outcome else {
            Issue.record("expected a forecast")
            return
        }
        #expect(forecast.monthsOfHistory == 4)
        #expect(forecast.month == TestClock.date(2027, 1, 1, hour: 0))
        #expect(december.trainedAt == TestClock.date(2026, 12, 15))
    }

    @Test("Changing a past month retrains the model")
    func editingHistoryRetrains() throws {
        let fixture = Fixture()
        try fixture.addHistory()
        fixture.service.refresh()

        try fixture.expenses.add(ExpenseDraft(amount: 500, date: TestClock.date(2026, 10, 20)))
        let training = fixture.service.refresh()

        #expect(training.retrained)
    }

    @Test("With too little history nothing is saved")
    func notEnoughData() {
        let fixture = Fixture()

        let training = fixture.service.refresh()

        #expect(training.outcome == .notEnoughData(monthsWithData: 0, monthsNeeded: 3))
        #expect(training.trainedAt == nil)
        #expect(fixture.store.load() == nil)
    }

    @Test("The saved model can be cleared")
    func clearing() throws {
        let fixture = Fixture()
        try fixture.addHistory()
        fixture.service.refresh()
        #expect(fixture.store.load() != nil)

        fixture.store.clear()

        #expect(fixture.store.load() == nil)
    }

    @Test("The view model shows what the service returns")
    func viewModel() throws {
        let fixture = Fixture()
        try fixture.addHistory()

        let viewModel = NextMonthViewModel(service: fixture.service)

        #expect(viewModel.forecast?.monthsOfHistory == 3)
        #expect(viewModel.training.retrained)
    }
}
