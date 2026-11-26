# Graph Report - Monetic  (2026-10-19)

## Corpus Check
- 37 files · ~310,907 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 6 file(s) not represented in the graph (top: (none) 1, .pbxproj 1, .xcworkspacedata 1)

## Summary
- 387 nodes · 746 edges · 22 communities (20 shown, 2 thin omitted)
- Extraction: 88% EXTRACTED · 11% INFERRED · 0% AMBIGUOUS · INFERRED: 85 edges (avg confidence: 0.85)
- Token cost: 706,795 input · 0 output

## Community Hubs (Navigation)
- Brand UI Components
- Category Palette & Tiles
- Budget Category Model
- README, Brand Tokens & CI
- Dashboard (ContentView)
- Type Scale & Category Detail
- App Entry & Data Store
- Transaction Entry & Editing
- Formatting & Monthly Budget
- Onboarding Category Picker Preview
- Settings Screen Preview
- Groups List Preview
- Add Expense Preview
- UI Demo Tests
- Budget Setup Onboarding Preview
- Category Detail Preview
- Dashboard Preview
- Spending Overview Preview
- Monetic Logo
- Logo Mark
- App Icon
- Unit Test Stub

## God Nodes (most connected - your core abstractions)
1. `BudgetCategory` - 33 edges
2. `.body` - 20 edges
3. `CategoryDetailView` - 18 edges
4. `Brand` - 17 edges
5. `AddTransactionView` - 17 edges
6. `BrandBackground` - 16 edges
7. `Transaction` - 16 edges
8. `CategoryTile` - 15 edges
9. `EditTransactionView` - 15 edges
10. `SpendingChartsView` - 15 edges

## Surprising Connections (you probably didn't know these)
- `Refresh profile cards workflow` --conceptually_related_to--> `Monetic iOS budgeting app`  [INFERRED]
  .github/workflows/ping-profile.yml → README.md
- `.body` --references--> `Brand`  [EXTRACTED]
  Monetic/DesignSystem/BrandComponents.swift → Monetic/DesignSystem/Brand.swift
- `.body` --references--> `Brand`  [EXTRACTED]
  Monetic/DesignSystem/BrandComponents.swift → Monetic/DesignSystem/Brand.swift
- `.body` --calls--> `BrandBackground`  [INFERRED]
  Monetic/MoneticApp.swift → Monetic/DesignSystem/BrandComponents.swift
- `.body` --calls--> `BrandBackground`  [INFERRED]
  Monetic/Views/AddTransactionView.swift → Monetic/DesignSystem/BrandComponents.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Native iOS tech stack** — readme_swiftui, readme_swiftdata, readme_charts, readme_appstorage [EXTRACTED 1.00]
- **Design system source files** — readme_design_system, readme_brand_swift, readme_categorypalette_swift, readme_brandcomponents_swift [EXTRACTED 1.00]
- **Claude Code plugin toolchain** — readme_claude_code, readme_everything_claude_code, readme_claude_mem, readme_superpowers [EXTRACTED 1.00]
- **Monthly Budget Setup Flow** — marketing_apppreviews_01_onboarding_month_header, marketing_apppreviews_01_onboarding_budget_amount_input, marketing_apppreviews_01_onboarding_save_budget_button [INFERRED 0.85]
- **Default Spending Category Groups Offered at Onboarding** — marketing_apppreviews_02_onboarding_categories_food_dining, marketing_apppreviews_02_onboarding_categories_entertainment, marketing_apppreviews_02_onboarding_categories_transport, marketing_apppreviews_02_onboarding_categories_shopping, marketing_apppreviews_02_onboarding_categories_bills_fees, marketing_apppreviews_02_onboarding_categories_health [EXTRACTED 1.00]
- **Dashboard budget overview: budget ring, spending donut, and category groups** — marketing_apppreviews_03_dashboard_monthly_budget_ring, marketing_apppreviews_03_dashboard_spending_overview_by_group, marketing_apppreviews_03_dashboard_category_groups [INFERRED 0.85]
- **Category Detail Screen Composition** — marketing_apppreviews_04_category_detail_category_detail_sheet, marketing_apppreviews_04_category_detail_category_summary_card, marketing_apppreviews_04_category_detail_expense_row, marketing_apppreviews_04_category_detail_add_expense_button [EXTRACTED 1.00]
- **Spending Dashboard Layout** — marketing_apppreviews_05_spending_overview_header_toolbar, marketing_apppreviews_05_spending_overview_monthly_budget_ring, marketing_apppreviews_05_spending_overview_spending_by_group_donut [EXTRACTED 1.00]
- **Monetic Home Screen Layout (toolbar, spending chart, groups list)** — marketing_apppreviews_06_groups_full_list_home_toolbar, marketing_apppreviews_06_groups_full_list_daily_spending_chart, marketing_apppreviews_06_groups_full_list_groups_list [INFERRED 0.85]
- **Monthly Budget Lifecycle (set, carry forward or re-prompt, display current)** — marketing_apppreviews_07_settings_monthly_budget, marketing_apppreviews_07_settings_repeat_monthly_budget, marketing_apppreviews_07_settings_monthly_budget_prompt, marketing_apppreviews_07_settings_this_month_budget_summary [INFERRED 0.85]
- **Expense Entry Form Fields** — marketing_apppreviews_08_add_expense_amount_field, marketing_apppreviews_08_add_expense_group_picker, marketing_apppreviews_08_add_expense_date_picker, marketing_apppreviews_08_add_expense_note_field [EXTRACTED 1.00]
- **Monetic Visual Identity System** — marketing_brand_monetic_logo_m_monogram_mark, marketing_brand_monetic_logo_wordmark, marketing_brand_monetic_logo_blue_violet_gradient, marketing_brand_monetic_logo_dark_background [INFERRED 0.85]
- **Monetic Brand Identity** — monetic_assets_xcassets_appicon_appiconset_appicon_m_monogram, monetic_assets_xcassets_appicon_appiconset_appicon_brand_gradient, monetic_assets_xcassets_appicon_appiconset_appicon_monetic_wordmark [EXTRACTED 1.00]

## Communities (22 total, 2 thin omitted)

### Community 0 - "Brand UI Components"
Cohesion: 0.07
Nodes (31): AmountEntryCard, .body, BrandCardModifier, BrandField, .body, BrandLogoMark, .body, .hasAsset (+23 more)

### Community 1 - "Category Palette & Tiles"
Cohesion: 0.08
Nodes (24): BrandBackground, .body, .isDark, CategoryTile, .body, .hue, CategoryPalette, String (+16 more)

### Community 2 - "Budget Category Model"
Cohesion: 0.08
Nodes (20): Charts, BudgetCategory, Transaction, CategoryDetailView, .emptyState, .hasLimit, .hue, .isOver (+12 more)

### Community 3 - "README, Brand Tokens & CI"
Cohesion: 0.06
Nodes (27): ping job (dispatch profile re-render), tonyp0/tonyp0 profile-cards.yml workflow_dispatch, PROFILE_DISPATCH_TOKEN secret, Refresh profile cards workflow, adaptive(), Color, AppStorage settings, Brand.swift (tokens: colors, surfaces, type, radii, spacing) (+19 more)

### Community 4 - "Dashboard (ContentView)"
Cohesion: 0.12
Nodes (15): BrandSectionHeader, .body, BudgetHeroCard, .isOver, .statsRow, ContentView, .body, GroupCard (+7 more)

### Community 5 - "Type Scale & Category Detail"
Cohesion: 0.12
Nodes (19): Brand, Radius, Space, BrandSegmented, .body, .body, .repeatCard, .header (+11 more)

### Community 6 - "App Entry & Data Store"
Cohesion: 0.12
Nodes (8): Foundation, MoneticApp, .body, .preferredScheme, StoreUnavailableView, .body, SwiftData, SwiftUI

### Community 7 - "Transaction Entry & Editing"
Cohesion: 0.12
Nodes (10): AddTransactionView, .body, .detailsCard, .effectiveCategory, .isValid, EditTransactionView, .body, .detailsCard (+2 more)

### Community 8 - "Formatting & Monthly Budget"
Cohesion: 0.12
Nodes (9): Currency, .code, .symbol, MonthKey, .body, SetBudgetView, .amountDisplay, .currentMonthName (+1 more)

### Community 9 - "Onboarding Category Picker Preview"
Cohesion: 0.20
Nodes (11): App Preview 02: Onboarding Categories Screenshot, Bills & Fees Category, Selectable Category Card Row, Onboarding Category Group Picker, Entertainment Category, Food & Dining Category, Get Started CTA with Selection Count, Health Category (+3 more)

### Community 10 - "Settings Screen Preview"
Cohesion: 0.27
Nodes (9): App Preview: Settings Screen, Appearance Theme Picker (Dark / Light / System), Blue-to-Purple Gradient Accent, MONETIC Gradient Wordmark (Version 1.0), Monthly Budget, Start-of-Month Budget Prompt, Repeat Monthly Budget Toggle, Settings Sheet (modal with Done button) (+1 more)

### Community 11 - "Groups List Preview"
Cohesion: 0.29
Nodes (6): App Preview 06: Groups Full List Screen, Add Group Action (+ Add button), Daily Spending Bar Chart (day of month vs $), Default Groups (Food & Dining, Entertainment, Transport, Shopping, Bills & Fees, Health, Subscriptions), Groups List (expense category cards), Home Toolbar (Settings, MONETIC wordmark, Edit, Add Expense)

### Community 12 - "Add Expense Preview"
Cohesion: 0.25
Nodes (7): App Preview 08: Add Expense Screen, Add Expense Sheet (Cancel / Save modal), Amount Field (currency-prefixed large numeric input), Date Picker (compact date pill), Decimal Pad Keyboard (auto-focused), Group Picker (emoji category chips: Bills & Fees, Entertainment, Food & Dining, Health), Note Field ("What was this for?")

### Community 14 - "Budget Setup Onboarding Preview"
Cohesion: 0.33
Nodes (6): App Preview 01: Onboarding (Monthly Budget Setup), Large Currency Amount Input ($0), Month Header (September 2026) with Cancel, Monthly Budget Entry Screen, Per-Month Budgeting Model, Save Budget Button (disabled until amount entered)

### Community 15 - "Category Detail Preview"
Cohesion: 0.33
Nodes (6): App Preview 04: Category Detail Screen, Add Expense Gradient CTA Button, Category Detail Sheet (Food & Dining), Category Summary Card (emoji icon, expense count, This Month total), Expense List Row (name, date, amount), Monthly Spending per Category

### Community 16 - "Dashboard Preview"
Cohesion: 0.40
Nodes (5): App Preview 03: Dashboard Screen, Expense Category Groups (Bills & Fees, Food & Dining, Health, Entertainment), Monetic Header Bar (Settings, Edit, Add), Monthly Budget Ring Card (Remaining / Spent / Budget), Spending Overview: By Group Donut Chart

### Community 17 - "Spending Overview Preview"
Cohesion: 0.40
Nodes (5): App Preview 05: Spending Overview Screen, Category Groups (Bills & Fees, Food & Dining, Health, Entertainment), Header Toolbar (Settings, MONETIC Gradient Wordmark, Edit, Add Expense), Monthly Budget Ring Card (Remaining / Spent / Budget), Spending Overview By Group Donut Chart

### Community 18 - "Monetic Logo"
Cohesion: 0.40
Nodes (5): Monetic Logo, Blue-to-Violet Brand Gradient, Dark Background Presentation, Monetic M Monogram Mark, MONETIC Spaced Wordmark

### Community 19 - "Logo Mark"
Cohesion: 0.67
Nodes (4): Monetic Brand Identity, Monetic Logo Mark (M Monogram), Blue-to-Purple Brand Gradient, Stylized 'M' Monogram with Ribbon Swoosh

### Community 20 - "App Icon"
Cohesion: 0.67
Nodes (4): Monetic App Icon (AppIcon.png), Blue-to-Purple Gradient Brand Palette, Stylized M Monogram Logo, MONETIC Wordmark

## Ambiguous Edges - Review These
- `Monetic M Monogram Mark` → `Ribbon / Flowing Money Motif`  [AMBIGUOUS]
  Marketing/Brand/monetic-logo.png · relation: rationale_for

## Knowledge Gaps
- **68 isolated node(s):** `.isDark`, `.clamped`, `.isOver`, `.isNearLimit`, `.body` (+63 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 114 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `String` connect `Category Palette & Tiles` to `Brand UI Components`, `Budget Category Model`, `Dashboard (ContentView)`, `Type Scale & Category Detail`, `App Entry & Data Store`, `Transaction Entry & Editing`, `Formatting & Monthly Budget`?**
  _High betweenness centrality (0.171) - this node is a cross-community bridge._
- **Are the 6 inferred relationships involving `BudgetCategory` (e.g. with `.sortedTransactions` and `.body`) actually correct?**
  _`BudgetCategory` has 6 INFERRED edges - model-reasoned connections that need verification._
- **What connects `.isDark`, `.clamped`, `.isOver` to the rest of the system?**
  _68 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Brand UI Components` be split into smaller, more focused modules?**
  _Cohesion score 0.07400555041628122 - nodes in this community are weakly interconnected._
- **Why does `BudgetCategory` connect `Budget Category Model` to `Category Palette & Tiles`, `Dashboard (ContentView)`, `App Entry & Data Store`, `Transaction Entry & Editing`?**
  _High betweenness centrality (0.073) - this node is a cross-community bridge._
- **Are the 10 inferred relationships involving `.body` (e.g. with `BrandBackground` and `BrandSectionHeader`) actually correct?**
  _`.body` has 10 INFERRED edges - model-reasoned connections that need verification._

### Low-confidence Hints
_AMBIGUOUS edges — the extractor was unsure. Verify before acting on these._

- **What is the exact relationship between `Monetic M Monogram Mark` and `Ribbon / Flowing Money Motif`?**
  _Edge tagged AMBIGUOUS (relation: rationale_for) - confidence is low._