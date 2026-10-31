# Pocketlens: Smart Expense and Receipt Tracker

Pocketlens is an iOS and iPadOS app for students and young professionals in Sri Lanka who pay by cash, card and online in foreign currency, and then lose track of where the money went. Photograph a receipt and the app reads it on the phone, fills in the merchant, date, total and category, and saves it with the place where it was spent. From those records it shows budgets, a map of where spending is highest, and forecasts for this month and next month.

It was built as the IOS course work for the BSc (Hons) in Computing at NIBM, Coventry University.

## What makes it different

- **Private by design.** Receipts are read on the device with Apple's Vision framework, and the forecasts are calculated on the device. No financial data is sent to an AI service, and receipt photos are never uploaded.
- **Locked behind Face ID or Touch ID**, with the device passcode as a fallback.
- **Works fully offline.** Everything is saved on the phone first and synced to the cloud automatically when the connection returns.

## Features

| Area | What it does |
|---|---|
| Account | Register, sign in, sign out and reset password with Firebase Authentication. Delete account and data (cloud and phone). |
| Privacy | Face ID or Touch ID lock on launch and when returning to the app. The previous user's data is erased when another user signs in. |
| Transactions | Add, edit and delete income and expenses with amount, date, merchant, category and note. Add from the Dashboard or the Activity tab. |
| Categories | Default and custom categories with icon and colour. |
| Search, filter, sort | Search merchant, note and category. Filter by type, category, date range and amount. Sort by date or amount. |
| Budgets | Monthly limit per category with a progress bar and On track, Near limit and Over budget status. |
| Multi-currency | Foreign purchases converted to LKR with a live exchange-rate API. The rate used is stored with the transaction and rates are cached for offline use. |
| Receipt scanning | Camera or photo picker. Text is read on the device. Merchant, date, total and currency are extracted, and a small on-device model suggests the category. Doubtful fields are highlighted for review, and corrections improve later suggestions. |
| Where you spend | The place is saved with a receipt (with permission). A map and a ranked list show the areas with the most spending. The list works offline. |
| Forecast, this month | Expected income, spending and spending per category for this month, learned from the last 3 months, with early warnings. |
| Forecast, next month | An on-device model that is retrained every month, with its accuracy measured by backtesting. |
| Budget plan | Turns the next-month forecast into suggested limits for a savings goal you choose, and applies them as your budgets. |
| Dashboard | Spending by category, monthly trend, predicted versus actual, and top spending areas. |
| Notifications | Local notifications for budget alerts, a forecast warning, a new month reminder and an optional reminder if you forget. They never contain money amounts. |
| Offline first, auto sync | Core Data is the source of truth. Pending changes sync to Cloud Firestore when the connection returns, the most recent edit wins, and deletes are kept as markers until synced. A badge shows Online, Syncing, Offline with the number of changes waiting, or Synced. |
| Widget | Home Screen and Lock Screen widget showing this month's spending against budget. |
| CSV export | Export every transaction to a spreadsheet file. |
| iPhone and iPad | Tab bar on iPhone. Sidebar, list and detail layouts on iPad. |
| Accessibility and look | VoiceOver labels, Dynamic Type, 44 point touch targets, warnings that use an icon and text as well as colour, and Light, Dark or System appearance. |

## How the forecasts work

- **This month:** the amount already recorded this month plus a recency-weighted average of what usually followed the same day of the month in the last 3 months.
- **Next month:** five simple models (weighted average, 3-month average, same as last month, smoothing and a ridge-regularised trend line) compete for every category. Each is tested on the user's own past months (walk-forward backtesting) and the one with the smallest error is kept. With fewer than 6 months of history the default weighted average is used. The model is retrained automatically in a new month and whenever past months change.
- **Budget plan:** essentials keep the forecast plus a 5% buffer, and only flexible categories are trimmed, never below 60% of their normal level, to reach the savings goal.

The method is explained in detail in `CODE_COMMENTS.md`, including its limits.

## Tech stack

| Tool | Used for |
|---|---|
| Swift and SwiftUI | All screens, iPhone and iPad. Swift Charts for the charts. |
| MVVM with protocol-based services | App structure and dependency injection (`AppContainer`), so tests can use fake services. |
| Core Data | Local store and source of truth, with a model written in code. |
| Firebase Authentication and Cloud Firestore | Accounts and the cloud copy of each user's data, with security rules so a user can only read and write their own records. |
| LocalAuthentication | Face ID and Touch ID lock. |
| Vision and VisionKit | Receipt scanning and text recognition on the device. |
| Natural Language | Category suggestion (an on-device word-matching classifier). |
| Core Location and MapKit | Saving where a receipt was scanned and drawing the spending map. |
| Network framework | Detecting online and offline to trigger the automatic sync. |
| WidgetKit | Home Screen and Lock Screen widget. |
| UserNotifications | Local notifications. |
| Swift Testing and XCTest | Unit tests and UI tests. |

## Project layout

```
IosCW/                    The app
  Core/                   Pure logic: parser, forecast, budget plan, notification rules, CSV, sync mapping
  Features/               SwiftUI screens, one folder per area
  Models/                 Small value types
  Persistence/            Core Data model, entities and controller
  Services/               Repositories, sign-in, sync engine, exchange rates, location, notifications
  ViewModels/             One view model per screen
PocketlensWidget/         The widget extension
Shared/                   Two files used by both the app and the widget
TestSource/               Unit tests (copied into the IosCWTests target)
UITestSource/             UI tests (copied into the IosCWUITests target)
firestore.rules           Firestore security rules
CODE_COMMENTS.md          Explanations of how each part works
TEST_CASES.md             Test plan, 149 manual test cases and a defect log
```

The source files contain no comments by design. The explanations live in `CODE_COMMENTS.md`.

## Requirements

- A Mac with Xcode 26 (the project targets iOS 26.2).
- An Apple ID for signing. A free account is enough for the simulator and for running on your own device.
- A Firebase project, only if you want accounts and cloud sync. Without it the app still runs, with a local-only sign-in and no cloud sync.

## Setup

1. **Open** `IosCW.xcodeproj` in Xcode and wait for the Swift packages to download. Firebase is pinned to version 11.15.0.
2. **Signing:** select the `IosCW` target and the `PocketlensWidget` target, go to Signing & Capabilities, and choose your Team for both. Both use the App Group `group.testdrtive.IosCW`. If you change the bundle identifier, change the group name in `Pocketlens.entitlements` and in `Shared/WidgetSnapshot.swift` too.
3. **Firebase (optional):**
   - Create a Firebase project and register an iOS app with bundle ID `testdrtive.IosCW`, or your own bundle ID.
   - Replace `IosCW/GoogleService-Info.plist` with the file from your project.
   - Turn on Email/Password under Authentication.
   - Create a Firestore database and publish the contents of `firestore.rules`.
4. **Run** on an iPhone simulator with Cmd+R. In Debug builds, Settings has a Developer section with "Load sample data" (9 months of fake transactions and budgets), which makes the charts and forecasts show something straight away.

The Settings screen shows whether Firebase is connected ("Sign-in service: Firebase" or "This phone only") and explains what is missing if it is not.

## Running the tests

1. **Unit tests:** File, New, Target, Unit Testing Bundle named `IosCWTests` (Testing System Swift Testing, Target to be Tested `IosCW`). Delete the generated file and copy everything from `TestSource/` into the `IosCWTests` folder.
2. **UI tests:** File, New, Target, UI Testing Bundle named `IosCWUITests`. Delete the generated files and copy `UITestSource/PocketlensUITests.swift` into the `IosCWUITests` folder.
3. Choose an **iPhone** simulator and press **Cmd+U**.

The UI tests launch the app with `-uitest`, which uses a local sign-in, an in-memory database and no Firebase, so they never touch real data. See `TEST_CASES.md` for the full test plan, the 10-minute smoke test, and the manual cases that need a real iPhone.

## Good to know

- **Camera scanning does not work on the simulator.** Use "Choose a receipt photo" there, or a real iPhone. Drag a receipt image onto the simulator window to add it to its Photos app.
- **Airplane mode does not exist on the simulator.** Turn off the Mac's Wi-Fi to test offline behaviour, or use a real iPhone.
- **The forecasts need history.** The forecast needs expenses in each of the last 3 months. Below that the app says "Not enough data yet".
- **Signing out erases the phone's copy** when cloud sync is on, because the full copy is in the cloud and comes back at the next sign in. The sign out box warns if changes have not uploaded yet.
- **Exchange rates** come from the free open.er-api.com service, which requires the credit "Rates by ExchangeRate-API". They are cached for 12 hours, with a manual rate as a last resort.
- `GoogleService-Info.plist` holds a Firebase client key. It is not a secret, because the data is protected by the Firestore security rules.

## Documents

- `CODE_COMMENTS.md`: how each part of the app works and why.
- `TEST_CASES.md`: test plan, test cases and results table.
