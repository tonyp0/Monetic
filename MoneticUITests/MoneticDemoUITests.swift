import XCTest

/// Drives a full feature tour of the app for a screen recording.
/// Not a correctness test — timings include deliberate pauses so the
/// recorded video reads clearly at human speed.
final class MoneticDemoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFullFeatureTour() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // MARK: Onboarding (there's a startup race between the onboarding
        // cover and the new-month budget sheet — handle whichever wins).
        let getStarted = app.buttons["Get Started"]
        if getStarted.waitForExistence(timeout: 6) {
            sleep(2)
            getStarted.tap()
        }

        // MARK: New-month budget prompt (shows automatically on first launch)
        let saveBudget = app.buttons["Save Budget"]
        XCTAssertTrue(saveBudget.waitForExistence(timeout: 10))
        sleep(1)
        // The real input is a 1x1, near-invisible decoy field (the big
        // number above it is the visible target) — tapping it directly is
        // too small a hit area for XCUITest to land reliably, so tap the
        // large visible amount display first (it carries the same
        // onTapGesture that focuses the field), then type into the field
        // element itself rather than relying on whatever XCUITest thinks
        // currently has keyboard focus.
        app.staticTexts["0"].tap()
        let budgetField = app.textFields.firstMatch
        XCTAssertTrue(budgetField.waitForExistence(timeout: 3))
        budgetField.typeText("450")
        sleep(1)
        XCTAssertTrue(app.staticTexts["450"].waitForExistence(timeout: 3))
        saveBudget.tap()

        // MARK: Dashboard — onboarding's starter groups are already in place
        sleep(2)

        // MARK: Add a custom group — Savings
        // The section header's "Add" pill sits inside a SwiftUI List row
        // that XCUITest can't reliably scroll-to-visible/hit-test (it
        // reports hit point {-1, -1} even though the button is fully on
        // screen), so tap its known on-screen position directly instead of
        // going through XCUITest's hit-testing for the element.
        let addGroupPill = app.buttons["addGroupButton"]
        XCTAssertTrue(addGroupPill.waitForExistence(timeout: 5))
        sleep(1)
        tapAddGroupPill(in: app)

        let nameField = app.textFields["e.g. Groceries, Rent, Fun Money"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        sleep(1) // let the sheet's slide-up animation finish before tapping
        nameField.tap()
        app.typeText("Savings")
        sleep(1)
        XCTAssertEqual(nameField.value as? String, "Savings")
        app.buttons["saveGroupButton"].tap()

        // MARK: Groups list, now including Savings
        sleep(1)

        // MARK: Open a starter group, then log an expense against it
        // Adding the expense from inside the category detail screen locks
        // the category automatically (no chip picker involved), which is
        // both more reliable to drive and a better-looking flow.
        let foodRow = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Food & Dining")
        ).firstMatch
        XCTAssertTrue(foodRow.waitForExistence(timeout: 5))
        foodRow.tap()

        let addExpenseButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Add Expense")
        ).firstMatch
        XCTAssertTrue(addExpenseButton.waitForExistence(timeout: 5))
        sleep(1)
        addExpenseButton.tap()

        let amountField = app.textFields["0.00"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        sleep(1) // let the sheet's slide-up animation finish before tapping
        amountField.tap()
        app.typeText("6.25")
        sleep(1)
        XCTAssertEqual(amountField.value as? String, "6.25")
        app.buttons["Save"].tap()

        // MARK: Category detail, now showing the logged expense
        XCTAssertTrue(
            app.staticTexts["$6.25"].waitForExistence(timeout: 5),
            "expense didn't actually land in Food & Dining"
        )
        let done = app.buttons["Done"]
        if done.waitForExistence(timeout: 5) {
            sleep(2)
            done.tap()
        }

        // MARK: Dashboard with updated ring + spending chart
        sleep(3)

        // MARK: Settings — appearance
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        // Same icon+text composite-label situation as the category chips.
        let lightButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Light")
        ).firstMatch
        if lightButton.waitForExistence(timeout: 5) {
            sleep(1)
            lightButton.tap()
            sleep(1)
            let darkButton = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "Dark")
            ).firstMatch
            darkButton.tap()
            sleep(1)
        }

        app.buttons["Done"].tap()

        // MARK: Final dashboard shot
        sleep(2)
    }

    /// The Groups-header "Add" pill sits inside a SwiftUI `List` row that
    /// combines several unrelated views under one `Group`; XCUITest's own
    /// scroll-to-visible/hit-test for it reports an invalid {-1, -1} point
    /// even though the button is fully on screen. Read the element's own
    /// (correctly reported) `frame` and tap that point directly instead of
    /// going through XCUITest's hit-testing for the element.
    private func tapAddGroupPill(in app: XCUIApplication) {
        let button = app.buttons["addGroupButton"]
        let frame = button.frame
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.midX, dy: frame.midY))
            .tap()
    }
}
