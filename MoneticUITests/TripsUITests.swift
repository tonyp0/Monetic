import XCTest

/// End-to-end check of the Trips tab: add a trip and see it listed with the
/// right countdown, then delete it.
///
/// Launches with -UITesting, so the app starts from an empty in-memory store
/// and first-launch settings every run. Trip dates are picked relative to the
/// test's own "now", so the expected countdown never goes stale.
final class TripsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Pinned locale so date-picker labels ("Monday, March 1") and the
        // decimal key are predictable.
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-UITesting", "YES"]
        app.launch()
    }

    func testAddingTripShowsItWithCountdown() throws {
        finishOnboarding()

        // MARK: Switch to Trips — starts empty
        let tripsTab = app.tabBars.buttons["tripsTab"]
        XCTAssertTrue(tripsTab.waitForExistence(timeout: 10), "Trips tab missing")
        tripsTab.tap()
        XCTAssertTrue(app.buttons["planTripButton"].waitForExistence(timeout: 5), "empty state didn't appear")

        // MARK: Add a trip
        let addTrip = app.buttons["addTripButton"]
        XCTAssertTrue(addTrip.waitForExistence(timeout: 5))
        addTrip.tap()

        let nameField = app.textFields["tripNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        let save = app.buttons["saveTripButton"]
        XCTAssertFalse(save.isEnabled, "Save should start disabled")

        nameField.tap()
        nameField.typeText("Spring Break")

        let destinationField = app.textFields["tripDestinationField"]
        destinationField.tap()
        destinationField.typeText("Cancún, Mexico")

        let daysAhead = 40
        let calendar = Calendar.current
        let departure = calendar.date(byAdding: .day, value: daysAhead, to: calendar.startOfDay(for: Date()))!
        pickDate(departure, in: app.datePickers["tripStartDatePicker"], sheetTitle: "New Trip")

        XCTAssertFalse(save.isEnabled, "Save needs an estimated total")

        let amountField = app.textFields["amountField"]
        amountField.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        amountField.typeText("2400")

        XCTAssertTrue(save.isEnabled, "Save should be enabled for a complete trip")
        save.tap()

        // MARK: The list shows it with the right countdown
        let row = app.buttons["tripRow_Spring Break"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "trip row didn't appear")
        waitForLabel(of: row, toContain: "in \(daysAhead) days")
        XCTAssertTrue(row.label.contains("Cancún, Mexico"), "row label: \(row.label)")
        XCTAssertTrue(row.label.contains("$2,400.00"), "row label: \(row.label)")
        XCTAssertFalse(app.buttons["planTripButton"].exists, "empty state should be gone")

        // MARK: Detail shows the totals and the savings placeholder
        row.tap()
        let total = app.staticTexts["tripTotal"]
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertEqual(total.label, "$2,400.00")
        XCTAssertTrue(app.staticTexts["tripDetailCountdown"].label.contains("in \(daysAhead) days"))
        XCTAssertTrue(app.otherElements["savingsPlanPlaceholder"].exists
                      || app.staticTexts["savingsPlanPlaceholder"].exists,
                      "savings plan placeholder missing")

        // MARK: Delete from the detail view, with confirmation
        let deleteButton = app.buttons["deleteTripButton"]
        if !deleteButton.isHittable { app.swipeUp() }
        deleteButton.tap()
        let confirm = app.buttons["Delete"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "delete confirmation didn't appear")
        confirm.tap()

        XCTAssertTrue(app.buttons["planTripButton"].waitForExistence(timeout: 5), "list should be empty again")
        XCTAssertFalse(app.buttons["tripRow_Spring Break"].exists)

        // MARK: The Budget tab is still there and unchanged
        app.tabBars.buttons["budgetTab"].tap()
        XCTAssertTrue(app.staticTexts["budgetTotal"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["budgetTotal"].label, "$500.00")
    }

    // MARK: - Steps

    /// Completes onboarding and the first-month budget prompt, checking on the
    /// way that onboarding covers the tab bar.
    private func finishOnboarding() {
        let getStarted = app.buttons["getStartedButton"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 10), "onboarding didn't appear")
        let tripsTab = app.tabBars.buttons["tripsTab"]
        XCTAssertFalse(tripsTab.exists && tripsTab.isHittable, "onboarding should cover the tab bar")
        getStarted.tap()

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
        XCTAssertTrue(app.staticTexts["budgetTotal"].waitForExistence(timeout: 10), "dashboard didn't appear")
    }

    /// Opens a compact date picker's calendar, pages forward to `date`'s month
    /// and taps that day.
    private func pickDate(_ date: Date, in picker: XCUIElement, sheetTitle: String,
                          file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "date picker missing", file: file, line: line)
        picker.tap()

        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US")
        dayFormatter.dateFormat = "EEEE, MMMM d"
        let dayLabel = dayFormatter.string(from: date)
        // Matches "Monday, March 1" with or without a trailing year or other
        // detail, but not "Monday, March 10".
        let dayButton = app.buttons.matching(NSPredicate(
            format: "label == %@ OR label BEGINSWITH %@", dayLabel, dayLabel + ","
        )).firstMatch

        let nextMonth = app.buttons.matching(NSPredicate(
            format: "identifier == 'DatePicker.NextMonth' OR label == 'Next Month'"
        )).firstMatch
        XCTAssertTrue(nextMonth.waitForExistence(timeout: 5), "calendar didn't open", file: file, line: line)
        for _ in 0..<3 where !dayButton.exists {
            nextMonth.tap()
            _ = dayButton.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(dayButton.exists, "no day button labelled \(dayLabel):\n\(app.debugDescription)", file: file, line: line)
        dayButton.tap()

        // Close the calendar by tapping outside it. Older iOS versions expose
        // a dismiss region; newer ones close on any tap outside, so tap the
        // sheet's title, which does nothing itself.
        let dismissRegion = app.otherElements["PopoverDismissRegion"]
        if dismissRegion.exists {
            dismissRegion.tap()
        } else {
            app.navigationBars.staticTexts[sheetTitle]
                .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .tap()
        }
        XCTAssertTrue(waitForNonExistence(of: nextMonth), "calendar didn't close", file: file, line: line)
    }

    // MARK: - Waiting

    private func waitForLabel(of element: XCUIElement, toContain expected: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label CONTAINS %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: 5)
        XCTAssertEqual(result, .completed,
                       "expected label containing \"\(expected)\", got \"\(element.label)\"", file: file, line: line)
    }

    private func waitForNonExistence(of element: XCUIElement) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: 5) == .completed
    }
}
