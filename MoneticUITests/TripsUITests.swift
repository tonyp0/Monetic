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

        // MARK: Detail shows the totals and the savings plan
        row.tap()
        let total = app.staticTexts["tripTotal"]
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertEqual(total.label, "$2,400.00")
        XCTAssertTrue(app.staticTexts["tripDetailCountdown"].label.contains("in \(daysAhead) days"))
        XCTAssertTrue(app.descendants(matching: .any)["savingsCard"].exists, "savings plan missing")

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

    func testEstimatingTripFromPerDiemRates() throws {
        finishOnboarding()
        app.tabBars.buttons["tripsTab"].tap()
        let addTrip = app.buttons["addTripButton"]
        XCTAssertTrue(addTrip.waitForExistence(timeout: 5))
        addTrip.tap()

        let nameField = app.textFields["tripNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Cancun Week")

        // MARK: Search the bundled per diem data and pick a place
        let destinationField = app.textFields["tripDestinationField"]
        destinationField.tap()
        destinationField.typeText("cancun")
        let result = app.buttons["destinationResult_DOS-MEXICO-CANCUN"]
        XCTAssertTrue(result.waitForExistence(timeout: 2), "Cancun didn't come up in search")
        result.tap()
        XCTAssertEqual(destinationField.value as? String, "Cancun, Mexico")

        // MARK: The breakdown appears straight away, from bundled data only
        let total = app.staticTexts["breakdownTotal"]
        XCTAssertTrue(total.waitForExistence(timeout: 1), "breakdown took more than a second")
        for item in ["lodging", "food", "localTransport", "activities"] {
            XCTAssertTrue(app.descendants(matching: .any)["breakdownRow_\(item)"].exists, "missing \(item) row")
        }
        XCTAssertTrue(app.staticTexts["flightsGapNote"].exists, "should flag that flights aren't included")
        let source = app.descendants(matching: .any)["estimateSourceLine"]
        XCTAssertTrue(source.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH 'Based on U.S. government per diem rates (U.S. Department of State, effective'"
        )).firstMatch.exists, "source line missing")
        XCTAssertTrue(app.staticTexts["styleAssumptionNote"].label.hasPrefix("Assumption:"))

        let save = app.buttons["saveTripButton"]
        XCTAssertTrue(save.isEnabled, "the estimate fills the total, so Save should be enabled")

        // MARK: Adding flights closes the gap
        let before = total.label
        let flights = app.textFields["flightsField"]
        flights.tap()
        flights.typeText("500")
        XCTAssertTrue(app.descendants(matching: .any)["breakdownRow_flights"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["flightsGapNote"].exists)
        XCTAssertNotEqual(total.label, before, "total should include flights")
        let estimated = total.label

        save.tap()

        // MARK: The list and detail show the per diem total in USD
        let row = app.buttons["tripRow_Cancun Week"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains(estimated), "row \(row.label) should show \(estimated)")
        row.tap()
        XCTAssertTrue(app.staticTexts["tripTotal"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["tripTotal"].label, estimated)
        XCTAssertTrue(app.descendants(matching: .any)["breakdownCard"].exists, "detail should show the saved breakdown")
        XCTAssertTrue(app.descendants(matching: .any)["breakdownRow_flights"].exists)
    }

    func testSavingForATripUpdatesRingAndDashboard() throws {
        finishOnboarding()

        // MARK: A $600 trip 40 days out: six weekly savings days, $100 each
        app.tabBars.buttons["tripsTab"].tap()
        let addTrip = app.buttons["addTripButton"]
        XCTAssertTrue(addTrip.waitForExistence(timeout: 5))
        addTrip.tap()
        let nameField = app.textFields["tripNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Lake Weekend")
        let destinationField = app.textFields["tripDestinationField"]
        destinationField.tap()
        destinationField.typeText("Somewhere quiet")
        let calendar = Calendar.current
        let departure = calendar.date(byAdding: .day, value: 40, to: calendar.startOfDay(for: Date()))!
        pickDate(departure, in: app.datePickers["tripStartDatePicker"], sheetTitle: "New Trip")
        let amountField = app.textFields["amountField"]
        amountField.tap()
        amountField.typeText("600")
        app.buttons["saveTripButton"].tap()

        let row = app.buttons["tripRow_Lake Weekend"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("On track"), "row should show the status chip: \(row.label)")
        row.tap()

        let progress = app.staticTexts["savingsProgressText"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertEqual(progress.label, "$0.00 saved of $600.00")
        XCTAssertEqual(app.staticTexts["savingsPerPeriod"].label, "Save $100.00 a week")
        XCTAssertEqual(app.staticTexts["savingsCountdown"].label, "40 days to go")
        XCTAssertEqual(app.staticTexts["savingsPercent"].label, "0%")

        // MARK: Put $150 aside
        addSavings("150")
        waitForLabel(of: progress, toContain: "$150.00 saved of $600.00")
        XCTAssertEqual(app.staticTexts["savingsPercent"].label, "25%")
        XCTAssertEqual(app.staticTexts["savingsPerPeriod"].label, "Save $75.00 a week")
        XCTAssertEqual(app.staticTexts["savingsStatus"].firstMatch.label, "Ahead")
        XCTAssertTrue(app.descendants(matching: .any)["contributionRow"].firstMatch.exists)

        // MARK: The Budget dashboard shows the trip, and its numbers don't move
        app.tabBars.buttons["budgetTab"].tap()
        let tripSavings = app.staticTexts["dashboardTripSavings"]
        XCTAssertTrue(tripSavings.waitForExistence(timeout: 5), "dashboard trip card missing")
        XCTAssertEqual(app.staticTexts["dashboardTripName"].label, "Lake Weekend")
        XCTAssertEqual(tripSavings.label, "Save $75.00 this week · $150.00 of $600.00")
        XCTAssertEqual(app.staticTexts["dashboardTripCountdown"].label.uppercased(), "NEXT TRIP · 40 DAYS TO GO")
        XCTAssertEqual(app.staticTexts["budgetTotal"].label, "$500.00")
        XCTAssertEqual(app.staticTexts["spentTotal"].label, "$0.00", "savings aren't spending")

        // MARK: Add from the dashboard
        app.buttons["dashboardAddSavingsButton"].tap()
        addSavingsInSheet("50")
        waitForLabel(of: tripSavings, toContain: "$200.00 of $600.00")
        XCTAssertEqual(app.staticTexts["spentTotal"].label, "$0.00")

        // MARK: Tapping the card opens the trip on the Trips tab
        app.staticTexts["dashboardTripName"].tap()
        XCTAssertTrue(progress.waitForExistence(timeout: 5), "trip didn't open")
        XCTAssertEqual(progress.label, "$200.00 saved of $600.00")
        XCTAssertTrue(app.tabBars.buttons["tripsTab"].isSelected)
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

    /// Taps Add to Savings on the trip screen and saves `amount`.
    private func addSavings(_ amount: String) {
        let add = app.buttons["addSavingsButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        if !add.isHittable { app.swipeUp() }
        add.tap()
        addSavingsInSheet(amount)
    }

    private func addSavingsInSheet(_ amount: String) {
        let field = app.textFields["amountField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Add to Savings didn't open")
        field.tap()
        field.typeText(amount)
        let save = app.buttons["saveContributionButton"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(waitForNonExistence(of: save), "sheet didn't close")
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
