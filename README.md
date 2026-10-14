# Monetic

<p align="center">
  <img src="Marketing/Brand/monetic-logo.png" alt="Monetic logo" width="140">
</p>

Monetic is a simple iOS budgeting app made to aid in the early financial literacy of kids in grades K-12. Building healthy money habits early is the main goal behind developing this app.

It tracks monthly spending in a way that feels lightweight and approachable. Instead of trying to be a full finance platform, the app focuses on the basics: setting a monthly budget, organizing expenses into groups, logging transactions, and seeing how your spending is trending throughout the month.

## What The App Does

The app helps users:

- set a monthly budget
- create and manage spending groups
- add one-time or recurring expenses
- review spending by category
- see a visual overview of monthly spending with charts
- customize app appearance and budget rollover behavior

When the app first launches, users are guided through a short onboarding flow that lets them start with a few default spending groups, then build from there.

## Why It Was Made

The main goal of Monetic is to aid in the early financial literacy of kids in grades K-12. Learning to set a budget, track spending, and see where money goes are skills that are best started young, and the app is designed to make those first steps simple and approachable for students.

Monetic was also made to offer a more personal and less overwhelming way to manage day-to-day spending. A lot of budgeting tools feel overly complex, cluttered, or built around features that casual users may not need. This app takes a simpler approach by focusing on the core habit of staying aware of where money is going each month.

The goal is to make budgeting feel easy to start, easy to keep up with, and useful at a glance.

## Framework And Tech Stack

Monetic is built with Apple's modern native iOS tools:

- `SwiftUI` for the user interface and navigation
- `SwiftData` for local data persistence
- `Charts` for spending visualizations
- `AppStorage` for lightweight settings like appearance and monthly budget preferences

The project currently targets `iOS 17.0+`.

## Design System

The interface is built on a single design system rather than SwiftUI defaults. Everything visual is defined in `Monetic/DesignSystem/`:

- `Brand.swift` — colors, surfaces, type scale, radii, and spacing tokens. Every surface is declared once and resolves per interface style.
- `CategoryPalette.swift` — the nine hues a spending group can be tinted with, plus the mapping that resolves color names stored by earlier versions.
- `BrandComponents.swift` — shared cards, buttons, the budget ring, progress bars, the segmented control, and the amount field.

The palette is taken from the app's logo: an electric blue running through violet into magenta, on near-black. The full gradient is reserved for a small number of signature moments — the budget ring, primary buttons, the wordmark, and selection states — so it reads as a brand mark rather than decoration.

Dark is the mode the brand is tuned for and the default for new installs. Light mode is fully supported and can be chosen in Settings.

## Main Features

- Monthly budget summary with remaining balance and progress tracking
- Expense grouping with custom names, colors, and icons
- Recurring monthly and yearly expense support
- Category detail views for reviewing transactions
- Onboarding flow with starter categories
- Settings for appearance and monthly budget rollover, including a one-tap option to roll last month's budget into the current month

### Budget Rollover

When "Repeat Monthly Budget" is on in Settings, Monetic no longer silently carries the old budget forward. Instead:

- At the start of a new month, the budget prompt leads with a **"Roll Over Last Month's Budget ($X)"** button so the amount carrying forward is explicit, with "Set a Different Amount" as a secondary option.
- A matching **"Roll Over Last Month's Budget"** row appears in Settings any time the current budget differs from the last one recorded, so the amount can be reapplied later even outside the new-month prompt.

With the toggle off, the app still prompts for a new budget each month, offering "Keep Last Month's Budget" as a fallback.

## Screenshots

<table>
<tr>
<td width="25%"><img src="Marketing/AppPreviews/03-dashboard.png" alt="Dashboard with remaining budget ring"></td>
<td width="25%"><img src="Marketing/AppPreviews/06-groups-full-list.png" alt="Spending groups list"></td>
<td width="25%"><img src="Marketing/AppPreviews/05-spending-overview.png" alt="Spending overview chart"></td>
<td width="25%"><img src="Marketing/AppPreviews/07-settings.png" alt="Settings screen"></td>
</tr>
<tr>
<td align="center"><sub>Dashboard</sub></td>
<td align="center"><sub>Spending groups</sub></td>
<td align="center"><sub>Spending overview</sub></td>
<td align="center"><sub>Settings</sub></td>
</tr>
</table>


## Marketing Website

A companion landing page showcases the app ahead of launch. It's a single self-contained HTML page (no build step, no framework) currently published as a private Claude artifact, pending a real domain.

### What's on it

- **Hero** — headline, pitch, and the live dashboard screenshot in a realistic device frame with an ambient blue/violet glow behind it
- **Feature walkthrough** — four alternating sections pairing real app screenshots (not mockups) with copy: spending groups, logging an expense, the spending-overview ring chart, and appearance/rollover settings
- **How it works** — a three-step onboarding preview (set a budget → pick starter groups → log as you go), each with a compact screenshot
- **Early access** — a waitlist form that opens the visitor's email client addressed to me, since there's no backend to store submissions yet
- **Trust strip** — a quick native-tech callout (SwiftUI, SwiftData, Swift Charts, iOS 17+)

### Brand consistency

Colors weren't picked separately from the app — they were sampled directly from the real UI and the logo: the electric blue → violet → magenta gradient, the near-black surfaces, and the coral/gold chart accents. Typography is Fraunces (headlines) + Sora (body) + JetBrains Mono (numbers), which the app's design system doesn't use, since the site can lean more editorial than the in-app UI.

### Status

Pre-launch. No App Store or TestFlight link yet — the CTA collects interest via email instead. Next step is moving it off the Claude artifact link onto a real domain (static host + DNS), at which point this section should get an update with the live URL.


## Running The Project

1. Open `Monetic.xcodeproj` in Xcode.
2. Choose an iPhone simulator or connected device.
3. Build and run the app.

## Status

This is a native iOS app under active development and currently stores data locally on device using SwiftData.

## Built With Claude Code

This project was developed using [Claude Code](https://claude.ai/code) with the following plugins and skills:

### Plugins
- **[everything-claude-code](https://github.com/anthropics/claude-code)** — core skill library providing SwiftUI patterns, feature development workflows, and code review tools
- **[claude-mem](https://github.com/anthropics/claude-code)** — persistent memory across sessions to maintain project context and coding preferences
- **[superpowers](https://github.com/anthropics/claude-code)** — meta-skills for planning, brainstorming, and execution workflows

### Skills Used
- `everything-claude-code:swiftui-patterns` — guidance on SwiftUI layout, state management, and navigation patterns
- `everything-claude-code:feature-dev` — structured workflow for implementing new features
- `everything-claude-code:code-review` — code quality review during development
- `superpowers:brainstorming` — planning app structure and feature design
- `superpowers:executing-plans` — step-by-step implementation of development plans
