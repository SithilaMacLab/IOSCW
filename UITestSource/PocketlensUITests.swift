import XCTest

@MainActor
final class PocketlensUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(signedIn: Bool) {
        app = XCUIApplication()
        app.launchArguments = signedIn ? ["-uitest", "-uitest-signedin"] : ["-uitest"]
        app.launch()
    }

    private func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
    }

    private func scrollTo(_ target: XCUIElement, maxSwipes: Int = 12) {
        var swipes = 0
        while !(target.exists && target.isHittable) && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
    }

    private func openTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "The \(name) tab is missing")
        tab.tap()
    }

    func testWelcomeScreenShowsTheMainActions() {
        launch(signedIn: false)

        XCTAssertTrue(app.staticTexts["Pocketlens"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Create account"].exists)
        XCTAssertTrue(app.buttons["Sign in"].exists)
    }

    func testRegisterRejectsAnInvalidEmail() {
        launch(signedIn: false)
        app.buttons["Create account"].tap()

        let email = app.textFields["Email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        email.typeText("not-an-email")

        let password = app.secureTextFields["Password"]
        password.tap()
        password.typeText("Password1")

        let confirm = app.secureTextFields["Confirm password"]
        confirm.tap()
        confirm.typeText("Password1")

        app.buttons["Create account"].tap()

        XCTAssertTrue(element(containing: "email address").waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.firstMatch.exists, "The user must not be signed in")
    }

    func testSignedInUserSeesAllFiveTabs() {
        launch(signedIn: true)

        for name in ["Dashboard", "Activity", "Budgets", "Forecast", "Settings"] {
            openTab(name)
            XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5), "\(name) did not open")
        }
    }

    func testAddingATransactionShowsItInActivity() {
        launch(signedIn: true)
        openTab("Activity")

        let add = app.buttons["Add transaction"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()

        let manual = app.buttons["Add manually"]
        if manual.waitForExistence(timeout: 2) {
            manual.tap()
        }

        let amount = app.textFields["Amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("1250")

        let merchant = app.textFields["Merchant"]
        merchant.tap()
        merchant.typeText("UI Test Cafe")

        app.buttons["Save"].tap()

        XCTAssertTrue(element(containing: "UI Test Cafe").waitForExistence(timeout: 5))
    }

    func testSampleDataFillsTheDashboardAndForecastBuildsABudgetPlan() {
        launch(signedIn: true)

        openTab("Settings")
        let loadSamples = app.buttons["Load sample data"]
        scrollTo(loadSamples)
        XCTAssertTrue(loadSamples.exists, "Run the tests with a Debug build")
        loadSamples.tap()

        openTab("Dashboard")
        let categories = app.staticTexts["Spending by category"]
        XCTAssertTrue(app.staticTexts["Predicted and actual"].waitForExistence(timeout: 10))
        scrollTo(categories)
        XCTAssertTrue(categories.exists)

        openTab("Forecast")
        let nextMonth = app.segmentedControls.buttons["Next month"]
        XCTAssertTrue(nextMonth.waitForExistence(timeout: 10))
        nextMonth.tap()
        let learned = app.staticTexts["How the model learned"]
        scrollTo(learned)
        XCTAssertTrue(learned.exists)

        let plan = app.buttons["Plan next month's budget"]
        scrollTo(plan)
        plan.tap()

        let apply = app.buttons["Apply as my budgets"]
        scrollTo(apply)
        XCTAssertTrue(apply.exists)
        apply.tap()

        let confirm = app.buttons["Apply plan"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        XCTAssertTrue(element(containing: "Budgets updated").waitForExistence(timeout: 5))

        openTab("Budgets")
        XCTAssertTrue(app.navigationBars["Budgets"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 5), "The plan should have created budgets")
    }

    func testSigningOutReturnsToTheWelcomeScreen() {
        launch(signedIn: true)

        openTab("Settings")
        let signOut = app.buttons["Sign out"]
        scrollTo(signOut)
        signOut.tap()

        let buttons = app.buttons.matching(identifier: "Sign out").allElementsBoundByIndex
        XCTAssertTrue(buttons.count >= 1)
        buttons.last?.tap()

        XCTAssertTrue(app.buttons["Create account"].waitForExistence(timeout: 10))
    }
}
