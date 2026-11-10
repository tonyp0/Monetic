# Prompt: Build Monetic's Test Suite

Paste everything below the line into Claude Code (or hand it to a developer) from the repo root.

---

You are adding an automated test suite to **Monetic**, a SwiftUI + SwiftData iOS 17 budgeting app (`Monetic.xcodeproj`, scheme `Monetic`). Today the only tests are an empty Swift Testing stub (`MoneticTests/MoneticTests.swift`) and a screen-recording demo (`MoneticUITests/MoneticDemoUITests.swift`) that is **not** a correctness test. Your job is to write tests that (1) prove adding expenses to every spending group actually works, and (2) act as a regression suite other developers run before merging.

## Read first

- `Monetic/Models/Category.swift` — `BudgetCategory` (`@Model`), its cascade relationship to transactions, and `monthlySpending(asOf:)`, `monthlySpendingPercentage(asOf:)`, `isOverBudget(asOf:)`.
- `Monetic/Models/Transaction.swift` — `Transaction` init normalizes `date` to start of day and clears `recurringFrequency` when `isRecurring == false`.
- `Monetic/Utilities/Formatting.swift` — `AmountInput.sanitize/parse`, `MonthKey`, `Currency.code`, `String.isEmojiIcon`.
- `Monetic/Views/OnboardingView.swift` — the 9 starter groups (`defaultCategories`) and `saveAndContinue()`.
- `Monetic/Views/AddCategoryView.swift`, `AddTransactionView.swift`, `EditTransactionView.swift`, `CategoryDetailView.swift`, `ContentView.swift` — the `save()` / `delete` / `reorderCategories` / `checkMonthRollover()` paths.
- `Monetic/MoneticApp.swift` — how the `ModelContainer` is built.

## Ground rules

1. **Framework:** Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`, `#require`) for unit/integration tests, matching the existing stub. XCTest only for UI tests. Use `@testable import Monetic`.
2. **Isolation:** every SwiftData test builds its own in-memory container:
   `ModelContainer(for: BudgetCategory.self, Transaction.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))`. Never touch the real on-disk store. Any test that writes `UserDefaults` (e.g. `selectedCurrencyCode`) must restore the previous value afterwards.
3. **Determinism:** never depend on "today". Build fixed dates with a `Calendar` + `DateComponents` helper and pass them through the `asOf:` parameters. Don't hard-code `"."` as the decimal separator — read `Locale.current.decimalSeparator` — so tests pass on any simulator locale.
4. **Don't change app behavior.** If a view's logic is `private` and untestable, you may do a *minimal, behavior-preserving* extraction (e.g. move the body of `AddTransactionView.save()` into a small `static func` or a `TransactionStore` helper the view calls), but keep the diff small and explain each extraction. Prefer testing through the models and `ModelContext` directly.
5. **Bugs found ≠ bugs fixed.** If a test reveals incorrect behavior, do not silently change app code. Wrap that expectation in `withKnownIssue("…")`, and list the bug in your final summary.
6. **Project wiring:** this `.xcodeproj` does *not* use synchronized folders, so every new `.swift` test file must be added to the `MoneticTests` (or `MoneticUITests`) target in `project.pbxproj`. Confirm by actually building and running the tests.
7. Keep tests readable for a K-12-focused, small team: one behavior per test, descriptive `@Test("…")` names, shared fixtures in a `TestSupport.swift` helper.

## 1. Adding expenses to each category (top priority)

File: `MoneticTests/CategoryTransactionTests.swift`

- Use a **parameterized test** (`@Test(arguments:)`) over all 9 onboarding starter groups (Food & Dining, Entertainment, Transport, Shopping, Bills & Fees, Health, Subscriptions, Travel, Work) **plus** a user-created custom group (e.g. "Savings", emoji icon, non-default). Source the starter list from the app rather than duplicating it if a small extraction makes that possible (e.g. make `defaultCategories` a `static let`).
- For each group, verify:
  - Inserting a `Transaction` with `category: group` and saving makes it appear in `group.transactions` (inverse relationship maintained by SwiftData — this is what `AddTransactionView.save()` relies on).
  - After fetching from a **fresh `ModelContext`** on the same container, the transaction is still there with the same amount, notes, normalized date, and category.
  - `monthlySpending(asOf:)` equals the expense amount for that month.
  - Adding multiple expenses sums correctly; expenses in group A never leak into group B's totals.
  - A recurring monthly and a recurring yearly expense can be added to every group and are stored with the right `recurringFrequency`.
- Mirror `AddTransactionView`'s validation: zero, negative, empty, and non-numeric amounts (via `AmountInput.parse`) must not produce a saveable transaction; a missing category must not either.
- Adding a group (`AddCategoryView.save()` behavior): trimmed name, `isDefault == false`, `sortOrder` equals the existing count; onboarding inserts the selected starters with `isDefault == true` and sequential `sortOrder`.

## 2. Essential regression tests

**`BudgetCategoryTests.swift` — spending math**
- One-time expense counts only in its own month/year (not the previous/next month, not the same month last year).
- Recurring **monthly**: counts in its start month and every later month; not in months before it started.
- Recurring **yearly**: counts in the same calendar month of the start year and later years; not in other months; not in earlier years.
- Unknown/empty `recurringFrequency` on a recurring transaction falls back to one-time behavior.
- Month boundaries: last day of month vs. first day of next month; December → January year rollover.
- `monthlySpendingPercentage`: `0` when `monthlyBudget == 0`; correct ratio otherwise.
- `isOverBudget`: false with no budget; false when spending **equals** budget; true when it exceeds it.

**`TransactionTests.swift`**
- `date` is normalized to start of day; `recurringFrequency` is `""` when not recurring even if a value is passed.

**`PersistenceTests.swift` — CRUD & relationships**
- Deleting a category cascades and deletes its transactions (`deleteRule: .cascade`).
- Deleting a single transaction removes it from its category and lowers `monthlySpending`.
- Editing a transaction's amount/date updates the category's totals.
- Reordering (`ContentView.reorderCategories` logic) assigns sequential `sortOrder` values.

**`FormattingTests.swift`**
- `AmountInput.sanitize`: strips letters/symbols, keeps one decimal separator, truncates to 2 decimal places, handles empty input.
- `AmountInput.parse`: accepts both `.` and `,`; returns `nil` for garbage.
- `MonthKey.key(for:)` returns `yyyy-MM` regardless of locale; `displayName(forKey:)` returns the raw key when unparsable.
- `Currency.code` prefers `UserDefaults["selectedCurrencyCode"]` when set (restore afterward).
- `isEmojiIcon`: true for emoji, false for SF Symbol names like `"tag"`.

**Month rollover (only if cheaply extractable)**
- If `ContentView.checkMonthRollover()` can be extracted into a pure function, test: no prompt when `budgetSetMonth` is the current month; prompt when it isn't; `lastMonthlyBudget` updated only when `monthlyBudget > 0`. Otherwise skip and note it.

## 3. One real UI smoke test

File: `MoneticUITests/AddExpenseUITests.swift` (leave `MoneticDemoUITests` alone).

- Add a DEBUG-only launch argument (e.g. `-UITesting`) handled in `MoneticApp.loadStore()` that uses an in-memory store and resets the relevant `@AppStorage` keys, so each run starts clean. Gate it behind `#if DEBUG`.
- Flow: complete onboarding → set a budget → open a starter group → add an expense → assert the amount appears in the group and the dashboard total updates.
- Use `waitForExistence` and accessibility identifiers (`addTransactionButton`, `addGroupButton`, `saveGroupButton`, `settingsButton`; add identifiers like `saveExpenseButton` where missing). **No `sleep()`.**

## 4. Make it easy for other developers

- Add a **"Running Tests"** section to `README.md` with:
  - Xcode: Product → Test (⌘U).
  - CLI: `xcodebuild test -project Monetic.xcodeproj -scheme Monetic -destination 'platform=iOS Simulator,name=iPhone 16'` (and `-only-testing:MoneticTests` for the fast unit suite).
  - A one-line rule: *run the unit suite before opening a PR; add a test with every bug fix.*
- Optional (ask before adding): a GitHub Actions workflow (`.github/workflows/tests.yml`) on a `macos-latest` runner that runs the unit suite on every pull request.

## Done when

- `xcodebuild test` passes locally on an iOS 17+ simulator, with the parameterized "add expense" test reporting a pass for **all 10 groups**.
- No test depends on the current date, the device locale, or leftover app data.
- Your final message lists: files added/changed, any app-code extractions and why, any `withKnownIssue` bugs discovered, and anything you skipped.
