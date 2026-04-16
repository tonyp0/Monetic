# MyBudget

MyBudget is a simple iOS budgeting app for tracking monthly spending in a way that feels lightweight and approachable. Instead of trying to be a full finance platform, the app focuses on the basics: setting a monthly budget, organizing expenses into groups, logging transactions, and seeing how your spending is trending throughout the month.

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

MyBudget was made to offer a more personal and less overwhelming way to manage day-to-day spending. A lot of budgeting tools feel overly complex, cluttered, or built around features that casual users may not need. This app takes a simpler approach by focusing on the core habit of staying aware of where money is going each month.

The goal is to make budgeting feel easy to start, easy to keep up with, and useful at a glance.

## Framework And Tech Stack

MyBudget is built with Apple's modern native iOS tools:

- `SwiftUI` for the user interface and navigation
- `SwiftData` for local data persistence
- `Charts` for spending visualizations
- `AppStorage` for lightweight settings like appearance and monthly budget preferences

The project currently targets `iOS 17.0+`.

## Main Features

- Monthly budget summary with remaining balance and progress tracking
- Expense grouping with custom names, colors, and icons
- Recurring monthly and yearly expense support
- Category detail views for reviewing transactions
- Onboarding flow with starter categories
- Settings for appearance and monthly budget rollover

## Running The Project

1. Open `MyBudget.xcodeproj` in Xcode.
2. Choose an iPhone simulator or connected device.
3. Build and run the app.

## Status

This is a native iOS app under active development and currently stores data locally on device using SwiftData.
