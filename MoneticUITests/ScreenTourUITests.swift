import XCTest

/// Captures every main screen in light and dark mode for visual review.
/// Not a correctness test: run it with `scripts/screenshots.sh`, which exports
/// the kept attachments (named `NN-screen-mode`) to `screenshots/<label>/`.
///
/// Launch-argument UserDefaults (`-appAppearance light`) override `@AppStorage`,
/// and `-SeedDemoData` fills the in-memory store (see `DemoData`).
final class ScreenTourUITests: XCTestCase {
    private let modes = ["light", "dark"]
    private var app: XCUIApplication!
    private var mode = ""

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Onboarding (fresh launch, no seed)

    func testOnboardingScreens() throws {
        for mode in modes {
            launch(mode: mode, seeded: false)

            let getStarted = app.buttons["getStartedButton"]
            XCTAssertTrue(getStarted.waitForExistence(timeout: 10), "onboarding didn't appear")
            snap("01-onboarding")

            getStarted.tap()
            XCTAssertTrue(app.buttons["saveBudgetButton"].waitForExistence(timeout: 10), "budget sheet didn't appear")
            waitUntilHittable(app.buttons["saveBudgetButton"])
            snap("02-set-budget")
        }
    }

    // MARK: Everything after onboarding (seeded)

    func testMainScreens() throws {
        for mode in modes {
            launch(mode: mode, seeded: true)

            // Home
            let spentTotal = app.staticTexts["spentTotal"]
            XCTAssertTrue(spentTotal.waitForExistence(timeout: 10), "home didn't appear")
            snap("03-home-top")

            scroll(toHittable: text(matching: "daily spending"))
            snap("04-home-chart")

            groupRow("Subscriptions")
            snap("05-home-groups")

            // Group with expenses, then one of its expenses and its edit sheet
            groupRow("Food & Dining").tap()
            XCTAssertTrue(app.staticTexts["groupMonthlySpent"].waitForExistence(timeout: 5))
            waitUntilHittable(app.buttons["addExpenseButton"])
            snap("06-category-detail")

            let groceries = app.staticTexts["Groceries"].firstMatch
            XCTAssertTrue(groceries.waitForExistence(timeout: 5))
            groceries.tap()
            let cancel = app.buttons["Cancel"]
            XCTAssertTrue(cancel.waitForExistence(timeout: 5), "edit expense didn't appear")
            waitUntilHittable(cancel)
            snap("10-edit-expense")
            cancel.tap()

            let menu = app.buttons["More"].firstMatch
            XCTAssertTrue(menu.waitForExistence(timeout: 5), "group menu not found")
            menu.tap()
            let editGroup = app.buttons["Edit Group"]
            XCTAssertTrue(editGroup.waitForExistence(timeout: 5))
            editGroup.tap()
            XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5), "edit group didn't appear")
            waitUntilHittable(app.buttons["Cancel"])
            snap("12-edit-group")
            app.buttons["Cancel"].tap()
            closeSheet(withButton: "Done")

            // Group with no expenses
            groupRow("Health").tap()
            XCTAssertTrue(app.staticTexts["No expenses yet"].waitForExistence(timeout: 5))
            waitUntilHittable(app.buttons["addExpenseButton"])
            snap("07-category-empty")
            closeSheet(withButton: "Done")

            // Add Expense from home: empty, then filled in
            let addTransaction = app.buttons["addTransactionButton"]
            XCTAssertTrue(addTransaction.waitForExistence(timeout: 5))
            addTransaction.tap()
            let amountField = app.textFields["amountField"]
            XCTAssertTrue(amountField.waitForExistence(timeout: 5))
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
            snap("08-add-expense-empty")

            amountField.typeText("12.50")
            let transport = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "Transport")
            ).firstMatch
            XCTAssertTrue(transport.waitForExistence(timeout: 5))
            transport.tap()
            waitUntilEnabled(app.buttons["saveExpenseButton"])
            snap("09-add-expense-filled")
            app.buttons["Cancel"].tap()

            // Add Group (see MoneticDemoUITests.tapAddGroupPill for the coordinate tap)
            scroll(toHittable: app.staticTexts["Groups"])
            let addGroup = app.buttons["addGroupButton"]
            XCTAssertTrue(addGroup.waitForExistence(timeout: 5))
            tapByFrame(addGroup)
            XCTAssertTrue(app.buttons["saveGroupButton"].waitForExistence(timeout: 5), "add group didn't appear")
            waitUntilHittable(app.buttons["Cancel"])
            snap("11-add-group")
            app.buttons["Cancel"].tap()

            // Settings
            let settings = app.buttons["settingsButton"]
            XCTAssertTrue(settings.waitForExistence(timeout: 5))
            settings.tap()
            XCTAssertTrue(app.buttons["currencyRow"].waitForExistence(timeout: 5))
            waitUntilHittable(app.buttons["Done"])
            snap("13-settings")
            app.buttons["Done"].tap()
        }
    }

    // MARK: Helpers

    private func launch(mode: String, seeded: Bool) {
        app?.terminate()
        self.mode = mode
        app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UITesting", "YES",
            "-appAppearance", mode,
        ]
        if seeded {
            app.launchArguments += ["-SeedDemoData", "YES"]
        }
        app.launch()
    }

    private func snap(_ screen: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "\(screen)-\(mode)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// A case-insensitive label match, for text shown with `.textCase(.uppercase)`.
    private func text(matching label: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
    }

    /// Scrolls to the home screen's row for a group and returns its name label.
    /// The spending chart's legend repeats group names above the list, so only
    /// a match below the "Groups" header counts.
    @discardableResult
    private func groupRow(_ name: String,
                          file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        func find() -> XCUIElement? {
            let header = app.staticTexts["Groups"]
            let top = header.exists ? header.frame.maxY : -.infinity
            return app.staticTexts.matching(identifier: name).allElementsBoundByIndex
                .first { $0.isHittable && $0.frame.minY > top }
        }
        for direction in [true, false] {
            for _ in 0..<7 {
                if let row = find() { return row }
                if direction { app.swipeUp(velocity: .slow) } else { app.swipeDown(velocity: .slow) }
            }
        }
        if let row = find() { return row }
        XCTFail("couldn't scroll to the \(name) group row", file: file, line: line)
        return app.staticTexts[name]
    }

    /// Scrolls the home list until `element` can be tapped: down first, then
    /// back up if it was already passed.
    private func scroll(toHittable element: XCUIElement,
                        file: StaticString = #filePath, line: UInt = #line) {
        func visible() -> Bool { element.exists && element.isHittable }
        for _ in 0..<6 where !visible() {
            app.swipeUp(velocity: .slow)
        }
        for _ in 0..<8 where !visible() {
            app.swipeDown(velocity: .slow)
        }
        XCTAssertTrue(element.isHittable, "couldn't scroll to \(element)", file: file, line: line)
    }

    private func closeSheet(withButton label: String) {
        let button = app.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 5))
        waitUntilHittable(app.buttons["settingsButton"])
    }

    /// Lets a sheet's slide-in animation finish before the screenshot.
    private func waitUntilHittable(_ element: XCUIElement) {
        wait(for: element, predicate: "exists == true AND hittable == true")
    }

    private func waitUntilEnabled(_ element: XCUIElement) {
        wait(for: element, predicate: "enabled == true")
    }

    private func wait(for element: XCUIElement, predicate format: String,
                      file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: format), object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: 5)
        XCTAssertEqual(result, .completed, "\(element) never matched \(format)", file: file, line: line)
    }

    /// For a button inside a List row whose hit point XCUITest reports as {-1, -1}.
    private func tapByFrame(_ element: XCUIElement) {
        let frame = element.frame
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.midX, dy: frame.midY))
            .tap()
    }
}
