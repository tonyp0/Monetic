import XCTest

/// End-to-end smoke test for the app's main job: logging an expense against a
/// group and seeing it reflected in the group and on the home screen.
///
/// Launches with -UITesting, so the app starts from an empty in-memory store
/// and first-launch settings every run.
final class AddExpenseUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Pinned locale so currency text ("$12.34") and the decimal key are predictable.
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-UITesting", "YES"]
        app.launch()
    }

    func testAddingExpenseToStarterGroupUpdatesGroupAndDashboard() throws {
        // MARK: Onboarding — keep the default starter selection
        let getStarted = app.buttons["getStartedButton"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 10), "onboarding didn't appear")
        getStarted.tap()

        // MARK: Set a monthly budget (prompted right after onboarding)
        let saveBudget = app.buttons["saveBudgetButton"]
        XCTAssertTrue(saveBudget.waitForExistence(timeout: 10), "budget prompt didn't appear")
        // The real input is a 1x1 hidden field; tapping the big visible "0"
        // focuses it (see MoneticDemoUITests for why).
        app.staticTexts["0"].firstMatch.tap()
        let budgetField = app.textFields["budgetAmountField"]
        XCTAssertTrue(budgetField.waitForExistence(timeout: 5))
        budgetField.typeText("500")
        XCTAssertTrue(app.staticTexts["500"].waitForExistence(timeout: 5))
        saveBudget.tap()

        // MARK: Dashboard starts with nothing spent
        let spentTotal = app.staticTexts["spentTotal"]
        XCTAssertTrue(spentTotal.waitForExistence(timeout: 10), "dashboard totals didn't appear")
        XCTAssertEqual(app.staticTexts["budgetTotal"].label, "$500.00")
        XCTAssertEqual(spentTotal.label, "$0.00")

        // MARK: Open a starter group and add an expense
        let foodRow = app.staticTexts["Food & Dining"]
        XCTAssertTrue(foodRow.waitForExistence(timeout: 5))
        foodRow.tap()

        let addExpense = app.buttons["addExpenseButton"]
        XCTAssertTrue(addExpense.waitForExistence(timeout: 5))
        addExpense.tap()

        let amountField = app.textFields["amountField"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        amountField.typeText("12.34")

        let saveExpense = app.buttons["saveExpenseButton"]
        XCTAssertTrue(saveExpense.isEnabled, "Save should be enabled for a valid amount")
        saveExpense.tap()

        // MARK: The group shows the expense
        let groupSpent = app.staticTexts["groupMonthlySpent"]
        XCTAssertTrue(groupSpent.waitForExistence(timeout: 5))
        waitForLabel(of: groupSpent, toEqual: "$12.34")

        // MARK: The dashboard total includes it
        app.buttons["Done"].tap()
        XCTAssertTrue(spentTotal.waitForExistence(timeout: 5))
        waitForLabel(of: spentTotal, toEqual: "$12.34")
    }

    /// Waits for SwiftUI to re-render a value instead of sleeping.
    private func waitForLabel(of element: XCUIElement, toEqual expected: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: 5)
        XCTAssertEqual(result, .completed,
                       "expected \"\(expected)\", got \"\(element.label)\"", file: file, line: line)
    }
}
