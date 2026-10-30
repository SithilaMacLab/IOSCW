# Code comments

The Swift files contain no comments. Everything worth explaining is kept here, grouped by file. This file sits outside the `IosCW/` folder on purpose so Xcode does not bundle it into the app.

## Persistence

**Persistence/CoreDataModel.swift**
- The Core Data model is built in code, so there is no `.xcdatamodeld` file. Keep it in step with `Entities.swift`: a new field needs adding in both places.
- `shared` is a single instance. Loading the same model twice makes Core Data complain about duplicate entity classes.
- `syncAttributes()` adds the four fields every record carries: `id`, `lastEdited`, `syncStateRaw`, `isSoftDeleted`.
- A to-many relationship uses `maxCount = 0`, which means unlimited.

**Persistence/Entities.swift**
- `SyncState` says whether a record has reached Firestore yet. The sync step uses it later.
- `SyncTracked` holds the shared sync fields. A deleted record is only marked (`isSoftDeleted`) and kept until the server has received it.
- Call `markEdited()` after every local change so the sync step knows to upload the record.
- `Expense` covers both expenses and income, told apart by `type`.
- `amount` is in the currency it was paid in. `exchangeRate` is the rate to LKR that was used, stored so old records never change. `amountLKR` is `amount * exchangeRate`.
- The class is named `ExpenseCategory` because Swift already has a built-in `Category` type.

**Persistence/PersistenceController.swift**
- `pocketlensDataDidChange` is posted after every save so view models can reload.
- The phone is the source of truth. Screens read and write here and never wait for the network.
- `save()` rolls back if the save fails, then rethrows.

## Core

- **AppContainer.swift**: builds the repositories once and hands them to the screens (dependency injection). Tests can pass an in-memory store or mock repositories. `preview()` gives previews an in-memory store.
- **SampleData.swift**: four months of fake transactions, a monthly salary and some budgets, for previews and demos. The forecast needs 3 months of history, so this also helps later. Sample dates stay in the past so the current month is never dated in the future.
- **ExpenseFilter.swift**: pure value types, easy to unit test. `hasActiveFilters` ignores the search box, so it drives the filter badge. The end date includes the whole day.
- **BudgetMath.swift**: a budget is "on track" under 80% used, "near limit" from 80% to 100%, and "over budget" from 100%. Each status has an icon and text as well as a colour.
- **SpendingStats.swift**: pure calculations behind the dashboard charts. `monthlyTrend` returns the last N months, oldest first.
- **DataChangeObserver.swift**: calls the handler on the main thread whenever a repository saves. Keep the returned token alive to keep receiving updates.
- **CurrencyFormatter.swift**: `lkr` gives "LKR 1,250.00". `compact` gives "1.2K" for chart axes.
- **Color+Hex.swift**: builds a colour from "#RRGGBB".

## Services

- **CategoryRepository.swift**: default categories are created on first launch only. Deleting a category keeps its transactions (they show as "Uncategorised") and deletes its budget. Default categories cannot be deleted. Names must be unique, ignoring case.
- **ExpenseRepository.swift**: `ExpenseDraft` holds everything the form collects. `exchangeRate` is 1 for LKR; the currency-conversion step fills it in later.
- **BudgetRepository.swift**: `setLimit` creates the category's budget or changes the limit if it already has one.
- **AuthServiceProtocol.swift**: screens depend on this protocol rather than Firebase directly, so unit tests can use a mock.
- **FirebaseAuthService.swift**: the whole file is wrapped in `#if canImport(FirebaseAuth)`, so the project still builds before the Firebase package is added. `configureIfPossible()` only calls `FirebaseApp.configure()` when `GoogleService-Info.plist` is in the app, otherwise the app would crash on launch. Firebase keeps the user signed in across launches by itself. Wrong password, unknown user and invalid credential all map to one "email or password is incorrect" message, so the app never reveals which emails have accounts.
- **DevAuthService.swift**: stand-in used when Firebase is not available (no package or no plist), and in previews. It accepts any valid email and password and only remembers the email in UserDefaults. It is for development only and never talks to a server.
- **AuthServiceFactory.swift**: picks Firebase when it is set up, otherwise the dev service.
- **AuthError.swift**: friendly messages shown on the sign-in screens.
- **BiometricAuthenticator.swift**: uses the `deviceOwnerAuthentication` policy, which means Face ID or Touch ID with the device passcode as the fallback. `unavailable` means the phone has no passcode or biometrics set up. `cancelled` covers the user tapping Cancel and the system interrupting the prompt (for example when the app moves to the background).
- **Info.plist**: `INFOPLIST_KEY_NSFaceIDUsageDescription` was added to both build configurations in the project file. Without it iOS will not allow Face ID.

## Auth and lock

- **AuthValidator.swift**: pure checks (email shape, password of 8 or more characters with a letter and a number), easy to unit test.
- **AuthViewModel.swift**: forms keep their own fields; the view model only holds the signed-in state, a working flag and the error or info message. Messages are cleared when a screen appears.
- **AppLockViewModel.swift**: starts locked on launch if the lock is on. The app locks when it moves to the background, and the lock screen asks for Face ID again when the app becomes active. Turning the lock on or off asks for Face ID first, so someone holding an unlocked phone cannot switch it off. If the phone loses its passcode while the lock is on, the lock turns itself off so the user is never stuck outside the app.
- **RootView.swift**: shows the welcome screens when signed out and the tab bar when signed in. The lock screen is drawn over the tab bar, which is hidden from VoiceOver while locked. `PrivacyCoverView` hides the app contents in the app switcher when the lock is on. Signing in or out releases the lock so a fresh sign-in is never followed by a lock prompt.
- **LockScreenView.swift**: asks for Face ID automatically when it appears and the app is active, and has a button to try again.
- **WelcomeView.swift**, **LoginView.swift**, **RegisterView.swift**, **ForgotPasswordView.swift**: each screen keeps its own text fields. The reset message is the same whether or not the email has an account.

## View models and screens

- **DashboardViewModel.swift**: `TrendPoint` is one bar in the income-vs-expenses chart; `kind` is "Income" or "Expenses".
- **BudgetsViewModel.swift**: `BudgetItem` is a budget plus what has been spent this month. Rows are sorted with the most urgent first. `categoriesWithoutBudget` feeds the add-budget picker.
- **ExpenseFormViewModel.swift** and **CategoriesViewModel.swift**: `save()` returns true when it worked, so the form can close.
- **ActivityViewModel.swift**: the list shows transactions filtered first, then sorted.
- **ActivityFilterView.swift**: works on a copy of the filter and only writes back when Apply is tapped.
- **CategoriesView.swift**: pushed from Settings, so it has no NavigationStack of its own.
- **CategoryFormView.swift**: colour and icon are picked from fixed grids.
- **DashboardView.swift**: the category legend shows icon, name and amount, so nothing depends on colour alone.
- **SettingsView.swift**: the "Load sample data" button is in debug builds only. Signing out asks for confirmation. Signing out keeps the data already on the phone; tying records to a user belongs to the sync step.
- **ContentView.swift**: the iPhone tab bar. The iPad sidebar (NavigationSplitView) comes in the final polish stage.
- **AppContainer.swift**: also holds the auth service, the exchange-rate service, the network monitor and the sync engine. The remote store is optional: without the Firestore package it is nil and sync stays off.

## Currency conversion

- **ExchangeRateService.swift**: uses the free open.er-api.com endpoint, which lists LKR and needs no key. One USD-based table is downloaded and cached in UserDefaults. A table younger than 12 hours is used without a network call. If the download fails, the old table is used and the rate is marked as cached (shown as "Offline: saved rate"). With no cache and no connection the form lets the user type a rate by hand. The free plan updates once a day and requires the "Rates by ExchangeRate-API" attribution, which the form shows.
- **ExchangeRateModels.swift**: `CurrencyConverter` converts through the table, so any pair works: LKR per unit = LKR per USD divided by code per USD. `RateSource` is `live` (fresh), `cached` (stale because offline) or `stored` (the rate saved with an existing transaction).
- **ExpenseFormViewModel.swift**: editing a foreign transaction keeps its saved rate until the currency changes, so old records never move. `canSave` also needs a usable rate. Only the amount in the paid currency is typed; the LKR value is `amount * rate` and is stored with the rate.
- **StaticExchangeRateService**: fixed rates for previews and tests.
- **Currency.swift**: the list offered in the picker. A transaction in a currency outside the list still shows its own currency when edited.

## Offline sync

- **Model**: each record carries an id, a last-edited time, a sync state (pending or synced) and a deleted marker. The phone is the source of truth; Firestore is a copy.
- **SyncRecord.swift** and **SyncMapper.swift**: the plain form of a record that travels to the server. Relationships travel as the category's id. Categories sync first, then budgets, then expenses, so links can be resolved.
- **SyncEngine.swift**:
  - Push: sends every pending record in batches of 400 (Firestore's limit is 500). A record is only marked synced if it was not edited again while the upload was running. A deleted record is removed from the phone only after the server has received the deletion; the deletion marker stays on the server so other devices learn about it.
  - Pull: asks for records edited since the last pull, per record type and per user. If the same record was edited in two places, the most recent last-edited time wins. Equal times keep the local copy. The last-pull time only moves forward after the changes are saved.
  - Triggers: the network coming back, the app becoming active, any local change (after a 2 second pause), and the Sync now button. Own saves during a sync are ignored so there is no loop.
  - Failure: status becomes "Sync problem" and a retry is scheduled after 5 seconds, then 15, 45, 135 and at most 300 seconds. A success resets the delay.
  - Up to 3 push-and-pull passes run in a row so edits made during a sync are not left waiting.
  - Local data belongs to one user. The user id is remembered; if a different user signs in, the local data is wiped and replaced from the cloud. The first user to sign in on a phone keeps the data already on it.
  - Times come from each phone's clock, so a phone with a badly wrong clock can win or lose conflicts unfairly.
- **CategoryRepository.swift**: default categories now get fixed ids made from their names, with a last-edited time of 1970 and the synced state. Two phones therefore share the same default categories instead of duplicating them, and a customised default from the cloud overwrites the plain local one.
- **FirestoreRemoteStore.swift**: wrapped in `#if canImport(FirebaseFirestore)`. Documents live at `users/{uid}/{categories|budgets|expenses}/{id}`. The Firestore disk cache is replaced by a memory cache, because Core Data is already the offline store and the disk cache would hold unconfirmed writes. Reads use `source: .server` so they fail quickly when offline. Each call has a 30 second timeout, because a Firestore write waits for the server and would otherwise hang when the connection drops mid-sync.
- **FirebaseBootstrap.swift**: starts Firebase once, only when `GoogleService-Info.plist` is present. Shared by sign-in and sync.
- **firestore.rules** (next to this file, not in the app): each signed-in user can read and write only their own `users/{uid}` documents. Paste it into Firestore Database > Rules and publish.
- **NetworkMonitor.swift**: wraps `NWPathMonitor`. Online means the path is satisfied.
- **Timeout.swift**: races an operation against a timer. Also holds the small `chunked(into:)` helper.
- **StableID.swift**: makes the same UUID from the same text (SHA-256, version 5 layout).
- **SyncBadgeView.swift** (replaces the old full-width banner, see "Sign-in screens and sync badge" below).
- **PersistenceController.swift**: `save(notify:)` can skip the change notification; the sync engine uses that when it only flips sync states. `wipeAll()` clears all three tables.

## Receipt scanning

- **Flow**: Activity tab, + menu, then "Scan a receipt" (document camera) or "Choose a receipt photo" (photo library). The images go to `ReceiptFlowView`, which shows "Reading your receipt…", then the normal transaction form pre-filled and marked for review. If nothing can be read the user can enter the transaction by hand. Receipts are read on the phone; the image is never uploaded (it is saved on the phone with the transaction, see the next section).
- **DocumentScannerView.swift**: wraps `VNDocumentCameraViewController`, which finds the receipt edges and flattens the perspective. It does not work on the simulator, so the menu item is disabled there; use the photo option to test. All pages of a multi-page scan are read and joined.
- **Info.plist**: `INFOPLIST_KEY_NSCameraUsageDescription` was added to both build configurations. Without it the app crashes when the camera opens. The photo picker needs no permission.
- **ReceiptTextRecognizer.swift**: Vision `VNRecognizeTextRequest` at the accurate level with language correction and automatic language detection. It runs off the main thread. Vision cannot read Sinhala or Tamil, so receipts in English work best. `RecognizedLine` is marked `nonisolated` because the project makes every type main-actor by default and this one is built on a background thread.
- **ReceiptLayout.swift**: Vision returns separate pieces of text, so "TOTAL" and "1,250.00" arrive apart. Pieces whose vertical centres are within 60% of a line height are joined into one row, left to right with two spaces between them. Rows run top to bottom (Vision's origin is bottom-left).
- **ReceiptParser.swift**: pure functions on rows, easy to unit test.
  - Merchant: the first of the top 6 rows that looks like a name (3 or more letters, mostly letters, at most 40 characters, not "invoice", "tel", "tax", a web address and so on). ALL CAPS is turned into Title Case.
  - Date: day-first formats like 05/10/2026 (Sri Lanka order), year-first 2026-10-05, and month names ("5 Oct 2026", "Oct 5, 2026"). If one number is above 12 it decides which is the day. Dates more than 2 days in the future or more than 5 years old are rejected, and so are rows about expiry or best-before dates.
  - Total: rows are ranked by keyword. Tier 3 is "grand total", "amount due", "net amount" and similar; tier 2 is "total"; tier 1 is "amount", "payable" or "due". Rows about subtotals, discounts, savings, cash, change, cards, items or tax totals are skipped. The lowest matching row of the best tier wins, and the amount used is the rightmost one. If the amount sits on the next row it is taken from there. With no keyword row at all, the largest amount on the receipt is used with low confidence.
  - Amounts understand 1,250.00 and also 1.250,00 and 12,50.
  - Currency: counts explicit codes (LKR, Rs, USD, EUR and so on) and symbols; a bare $ is treated as USD with low confidence; nothing found means LKR.
  - Confidence: Vision's own confidence in accurate mode is mostly 0.5 or 1.0, so it only counts for 60% to 100% of the score (`0.6 + 0.4 * confidence`). The rest comes from how the field was found (for example 1.0 for a "grand total" row, 0.45 for the largest-amount fallback). A field below 0.6 is flagged for review.
- **CategorySuggester.swift**: a small on-device Naive Bayes text classifier built with Apple's NaturalLanguage tokenizer. It is rebuilt each time from three sources: the category names, a built-in word list for the default categories (Sri Lankan brands like Keells, Dialog, PickMe, Osusala), and the user's own past transactions. Merchant words count double. An exact or near match with a merchant the user has used before wins outright (confidence 0.95). Otherwise a suggestion needs at least 40% probability, and below 60% it is flagged. This replaces a Create ML model, which can only be trained on a Mac; the same interface can be swapped for a Core ML model later.
- **Learning from corrections**: nothing extra is stored. When the user fixes a category and saves, that transaction becomes training data, so the next receipt from the same merchant gets the corrected category.
- **ExpenseFormView.swift** and **ExpenseFormViewModel.swift**: the review screen is the normal form with a receipt picture on top. A flagged field gets an orange row, a warning icon and a short text ("Check the amount"), so it never relies on colour alone. The warning goes away as soon as the user edits that field. The summary line says how many fields need checking, or that everything looks right. Foreign-currency receipts use the same exchange-rate logic as manual entry.
- **ReceiptFlowView.swift**: `ScannedReceipt` is the identifiable wrapper used to present it as a sheet.
- **ActivityView.swift**: the camera cover is dismissed first and the review sheet opens from its `onDismiss`, because SwiftUI cannot present two covers at once.

## Receipt photo, place and spending map

- **Model change**: `Expense` gained four optional fields: `latitude`, `longitude`, `placeName` and `receiptImageData`. They are optional so older records stay valid. The photo attribute uses Core Data's external binary storage, so large images live in files next to the database instead of inside it.
- **Photo handling** (`ReceiptImageEncoder.swift`): the first page of the scan is shrunk so the longest side is at most 1600 pixels and saved as a JPEG at 70% quality, usually a few hundred kilobytes. The photo is deliberately never synced: it stays on the phone, matching the proposal's promise that receipts are not uploaded. Deleting a transaction clears its photo straight away. Editing a transaction keeps its photo unless the form is saved without one.
- **Store rebuild** (`PersistenceController.swift`): the Core Data model is written in code, so Core Data cannot work out how to upgrade an old database when fields are added. If the store fails to open with a model-mismatch error, it is deleted and recreated, and the "last pulled" times are forgotten so the next sync downloads everything again from the cloud. Changes that had not synced yet are lost in that case. This is meant for development; a published app would need a proper versioned model.
- **Place** (`Models/Place.swift`): a latitude, a longitude and an optional area name. `Expense.place` packs and unpacks the three stored fields.
- **LocationService.swift**: asks for "when in use" permission only when a place is first needed, then takes one location fix (hundred-metre accuracy, 10 second limit) and looks up the area name ("Bambalapitiya, Colombo") with Apple's geocoder. The geocoder needs internet; offline the place is kept without a name. `CLGeocoder` is marked deprecated in the newest SDK in favour of MapKit's geocoding requests, but it still works.
- **Form behaviour**: scanning a receipt asks for the place automatically when the review screen opens. A new manual transaction gets an "Add current place" button. Editing an old transaction never offers the current place, because it would be wrong for a past purchase, but an existing place can be removed. If permission is denied the form says so, offers an "Open Settings" button, and saves the receipt without a place. Place names reach the cloud with the transaction; the photo does not.
- **Sync** (`SyncMapper.swift`): `latitude`, `longitude` and `placeName` travel with the expense. A record from the cloud without them clears the place, because the cloud copy is the whole truth.
- **SpendingAreas.swift**: groups expenses (not income) by area name, ignoring letter case. Expenses with coordinates but no name are grouped into 0.01 degree cells (about 1 km) and labelled "Near 6.89, 79.86". Each area's marker is the average of its points. Areas are ranked by total LKR. It also counts expenses with no place, so the map can say how many are missing.
- **SpendingMapView.swift**: a segmented period (this month, 3 months, all time), a MapKit map with numbered circles that grow with spending, and a ranked list underneath. Tapping a row zooms to that area. The numbers sit inside the circles and in the list, so rank never depends on colour alone. The map background needs internet but the list does not, as the proposal requires.
- **DashboardView.swift**: a "Where you spend" card shows this month's top three areas and links to the map.
- **SampleData.swift**: sample expenses are spread over seven Colombo areas so the map has something to show.
- **Info.plist**: `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` was added to both build configurations. Without it the location request fails silently.

## Monthly forecast

- **What it predicts**: this month's income, this month's spending, and this month's spending per category, learned from the last 3 full months. This is what the proposal describes; it is not a prediction of the next 3 months. The Forecast tab (`ForecastView.swift`) shows it, and the Dashboard has a small "Predicted and actual" card.
- **Not enough data**: the forecast only runs when each of the last 3 calendar months contains at least one expense. Otherwise both screens say "Not enough data yet" and how many of the 3 months have data. Income alone does not count. The sample data (Settings, Developer) creates 4 months so the screen can be demonstrated.
- **ForecastEngine.swift**: pure functions on plain `ForecastEntry` values (a copy of the fields it needs), so it can be unit tested without Core Data. The method, for income, expenses and every category separately:
  1. Add up what was recorded so far this month. That is the "actual".
  2. For each of the 3 previous months, add up what was recorded after the same day of the month (day 12 this month means everything after day 12 last month, and so on; short months are clamped to their last day). That is how much the month still had to come at this point.
  3. Take a weighted average of those 3 numbers, with weights 1, 2 and 3 for the oldest to the newest month, so recent behaviour counts more.
  4. Expected for the month = actual so far + that average.
  5. The "likely between" range is actual so far plus the smallest and the largest of the 3 leftovers.
- **Why not "average month"**: an average month would be wrong for income. A salary paid on day 1 is already in "so far", and the earlier months also had it before the cutoff, so nothing extra is added. On the last day of the month the leftover is zero and the forecast equals the actual.
- **Categories**: grouped by category id. Categories with an expected amount of zero are hidden. They are sorted by expected amount.
- **Early warnings** (`ForecastViewModel.swift`): a warning shows when expected spending is above expected income (only if some income is expected), and for each category whose expected amount is above its budget limit. Warnings use an icon and text, never colour alone. Category rows with a budget show the forecast status using the same on track, near limit (80%) and over budget (100%) rules as the Budgets tab.
- **Chart**: bars for the last 3 months and this month. This month's bar is stacked: solid for spent so far, pale for the expected rest. The legend names both, and the chart has a spoken summary for VoiceOver.
- **Offline and privacy**: everything is calculated on the phone from the local database and nothing is sent anywhere.
- **Other edits**: `ChartCard` in `DashboardView.swift` is no longer private so the Forecast screen can reuse it. `ContentView.swift` now passes the container to `ForecastView`.

## Home Screen widget

- **How the widget gets its data**: a widget is a separate program and cannot open the app's Core Data store. Instead the app writes a small summary (`WidgetSnapshot`) as JSON into an App Group, a shared storage area both programs can read, and then asks WidgetKit to refresh. The widget only reads that summary. No receipt photos, merchants or places go into it.
- **WidgetSnapshot.swift**: the summary (month, spent, income, total budget limit, spent inside budgeted categories, expected month-end spending, up to 6 budget lines) and `WidgetStore`, which saves and loads it from the App Group `group.testdrtive.IosCW`. If the bundle identifier of the app changes, this id must change with it, and the App Group capability must be added again. This file is shared with the widget target.
- **BudgetStatus.swift**: moved out of `BudgetMath.swift` so the widget can use the same on track, near limit and over budget rules without needing Core Data. Shared with the widget target.
- **WidgetSnapshotBuilder.swift**: pure function that builds the summary from plain `ForecastEntry` values and the budget limits, so it can be unit tested. The gauge compares only spending inside budgeted categories with the total of all limits, so spending without a budget does not make it look worse than it is. The expected month-end spending comes from the forecast and is left out when there is not enough history.
- **WidgetPublisher.swift**: builds the summary and saves it. It runs after every data change (waits 1 second after the last change so a sync of many items refreshes once), when the app opens, when it comes to the foreground, and when the user signs in or out. When nobody is signed in it deletes the summary, so the widget goes back to "Open Pocketlens". The preview and test containers use `NoWidgetPublisher`, so sample data never reaches a real widget.
- **Widget code** (`WidgetSource/`, outside the app folder so it is not bundled into the app):
  - `PocketlensWidgetBundle.swift`: the entry point of the widget extension.
  - `PocketlensWidget.swift`: the provider, the views and a sample for previews. Sizes: small (spent, budget bar, status), medium (spent, expected, top 3 budgets), and two Lock Screen sizes (rectangular and circular gauge).
  - Timeline: one entry now and one at the start of next month, refreshed at least hourly. After the month changes, the old summary is no longer shown; the widget asks the user to open the app, because last month's numbers would be wrong.
- **Privacy**: every amount is marked `privacySensitive()`, so iOS hides it while the phone is locked and on the Lock Screen unless the user allows it. The widget has no Face ID of its own, which is how widgets work on iOS; the proposal asks for a widget that shows spending without opening the app.
- **Status uses text and an icon as well as colour**, and each block is read by VoiceOver as one item.

### Adding the widget target in Xcode (done by hand on the Mac)

1. File, New, Target, Widget Extension. Product name `PocketlensWidget`. Untick Live Activity, Control and Configuration App Intent. Finish. If asked to activate the scheme, press Cancel.
2. In the file list under `PocketlensWidget`, move the generated `PocketlensWidget.swift` and `PocketlensWidgetBundle.swift` (and any other generated .swift files) to the Trash. Keep the assets and the Info file.
3. In Finder, copy the two files from `WidgetSource/` into the `PocketlensWidget` folder. Xcode picks them up by itself. If it does not, drag them in and tick only the widget target.
4. Select `IosCW/Core/WidgetSnapshot.swift`, open the File inspector (right panel), and tick `PocketlensWidget` under Target Membership. Do the same for `IosCW/Core/BudgetStatus.swift`. The app target stays ticked.
5. Select the project, then the `IosCW` target, Signing & Capabilities, + Capability, App Groups, + and add `group.testdrtive.IosCW`. Select the `PocketlensWidget` target and add the same group.
6. Run the app scheme, sign in, then long-press the Home Screen, press +, find Pocketlens and add the widget.

## Final polish: iPad, CSV export, accessibility, delete account, unit tests

### iPad layout
- **ContentView.swift**: uses the newer `Tab` API with `.tabViewStyle(.sidebarAdaptable)`. On iPhone it is the normal tab bar; on iPad it becomes a sidebar that the user can collapse, as in the prototype.
- **ActivityView.swift**: when the horizontal size class is regular (iPad, and the iPhone Max in landscape) it uses a `NavigationSplitView`: the transaction list on the left and `ExpenseDetailView` on the right, with an empty "Select a transaction" state. On iPhone it keeps the stack and the edit sheet. The search, sort, filter and add controls are shared between both layouts. Deleting the selected row clears the detail pane.
- **ExpenseDetailView.swift**: a read-only page with the amount, category, date, note, place and the saved receipt photo, and an Edit button that opens the normal form.
- **DashboardView.swift** and **ForecastView.swift**: the cards sit in a `LazyVGrid` with adaptive columns (at least 340 points wide), so they are one column on iPhone and flow into two or more on iPad.

### Accessibility and Dynamic Type
- **AdaptiveRow.swift**: lays a row out side by side normally, and stacks it vertically at the accessibility text sizes so amounts are never cut off. Used by the transaction rows, budget rows, forecast rows and the detail page.
- **Transaction rows** read as one sentence ("Keells, Expense of LKR 1,250.00, Groceries, 5 October 2026") instead of loose pieces and a minus sign.
- **Category icons** grow a little with the text size (capped at 1.6 times) so they stay in proportion. Rank badges can widen instead of clipping.
- **Chart cards**: titles are marked as headings for the VoiceOver rotor. The donut chart also reads out the top three categories.
- **Pickers**: colour swatches read "Colour 3 of 12" and icons read their name without dots, instead of a hex code.
- **Already in place from earlier steps**: warnings use an icon and text as well as colour, controls are at least 44 points tall, and the map list works without the map.

### CSV export
- **CSVExporter.swift**: pure functions. One row per transaction, oldest first, with ISO dates (2026-10-05), original amount and currency, the exchange rate, the LKR amount, note and place. Line breaks are Windows style as the CSV standard says. Fields with commas, quotes or line breaks are quoted. Text starting with `=`, `+`, `-` or `@` gets a leading apostrophe, so a merchant name read from a receipt cannot run as a spreadsheet formula.
- **ExportViewModel.swift**: writes the file to the temporary folder with a UTF-8 byte order mark so Excel shows names correctly, then opens the share sheet (`ShareSheet.swift`, which wraps `UIActivityViewController`). The previous export file is deleted when the next one is made, not when the sheet closes, because AirDrop and Mail may still be reading it. Receipt photos are not included. With no transactions the user is told there is nothing to export.

### Delete account and data
- **Where**: Settings, Data, "Delete account and data". A sheet lists what will be deleted, asks for the password, then asks for a final confirmation.
- **AccountDeletionService.swift** runs these steps in this order, so a failure never leaves the user half-deleted:
  1. Refuse if nobody is signed in, or if cloud sync is on and the phone is offline (otherwise the cloud copy would be left behind).
  2. Re-enter the password with Firebase (`reauthenticate`). Firebase requires a recent sign-in to delete an account, and this also confirms the user is who they say.
  3. Stop the sync engine and wait for any running sync to finish, so nothing is uploaded again afterwards.
  4. Delete the cloud data (`RemoteStore.deleteAll`: categories, budgets and expenses in batches of 400, then the user document), then delete the Firebase account. If either fails the sync engine is resumed and the error is shown; the local data is untouched.
  5. Forget the sync bookkeeping, wipe the local database (receipt photos go with it), put the default categories back, clear the widget, switch the app lock off and return to the welcome screen.
- **Dev mode** (no Firebase): the same steps run with the local sign-in only.
- **SyncEngine.swift** gained `suspendForAccountDeletion`, `resumeAfterFailedDeletion`, `forgetAccount`, `syncAndWait` and `sessionChangedAndWait`. The last two are the same code the app already used, made awaitable so tests do not have to wait on timers. `NetworkMonitor` gained a switch to run without the real network for tests.
- **firestore.rules** already allow a signed-in user to delete everything under their own `users/{uid}`, so no rule change is needed.

### Unit tests (`TestSource/`)
- The tests use Swift Testing (`import Testing`) and cover the areas named in the proposal: the receipt parser and row grouping, budget maths, the forecast, currency conversion and rate caching, and the sync rules. They also cover the CSV export, the widget summary, delete account, sign-in checks, spending areas and the category suggester. Each test suite is marked `@MainActor` because the app makes every type main-actor by default.
- **Sync rules covered**: pending changes are uploaded then marked synced; default categories are not uploaded; a newer cloud change replaces the local copy; an older cloud change does not; a cloud deletion removes the local copy; a local deletion is uploaded as a tombstone and then removed; offline changes wait and upload when the connection returns; a failure keeps changes pending; a different user signing in clears the data; the same user keeps it; signed out means nothing is uploaded.
- **TestSupport.swift** holds the fakes: a fake cloud store, a fake sign-in service and an event log that records the order of calls. Dates in tests use a fixed UTC calendar so the results do not depend on the time zone or the day the tests run.
- **Known behaviour the tests do not change**: during a sync the app uploads first and downloads second, so when the same item was edited on two phones before either synced, the phone that syncs last wins on the server. The "newest edit wins" rule applies to what is downloaded.

### Adding the test target in Xcode (done by hand on the Mac)
1. File, New, Target, Unit Testing Bundle. Product name `IosCWTests`, Testing System "Swift Testing", Target to be tested `IosCW`.
2. Move the generated `IosCWTests.swift` (and any UI test files) to the Trash.
3. In Finder copy all the files from `TestSource/` into the `IosCWTests` folder. Xcode picks them up by itself. If it does not, drag them in and tick only the test target.
4. Press Command-U to run all tests. Each test name appears in the Test navigator.

## Sign-in screens and sync badge

### Sign-in screens
- **Flow**: Welcome, then Create account or Sign in. Sign in has "Forgot password?". The "Sign in" and "Create account" links at the bottom of those two screens swap one for the other, so the back stack never grows into a loop. `WelcomeView` owns the navigation path (`AuthRoute`: login, register, forgot) and hands each screen an `AuthActions` with `go` and `replace`.
- **AuthComponents.swift** holds the shared pieces:
  - `AuthHeroView`: the big illustration, drawn in code from shapes and SF Symbols (no image files): a soft circle, a dashed ring, a tilted gradient tile with the main icon, and small floating chips. Each screen has its own icon and chips (welcome: scan, chart, map pin; sign in: lock and Face ID; register: person with plus; reset: envelope and key). The chips drift slowly, which is switched off when Reduce Motion is on. It is hidden from VoiceOver and shrinks at the accessibility text sizes.
  - `AuthScreen`: the page frame (gradient background, hero, title, subtitle, scrolling content, width limited to 480 for iPad). The keyboard hides when the user scrolls.
  - `AuthTextField` and `AuthPasswordField`: rounded fields with a leading icon, a highlight ring on the field that has focus, and a show or hide eye button on password fields (44 point tap area). Pressing Return moves to the next field, and on the last field it submits.
  - `AuthPrimaryButton`: a full-width prominent button with a spinner while working.
  - `RequirementRow`: the live checklist on Create account (8 characters, a letter and a number, passwords match). Each row has an icon and text, so it is not colour only.
- **AuthMessageView.swift**: errors and confirmations are now soft coloured cards with an icon. `AuthSubmitButton` was removed.
- The checks themselves have not changed (`AuthValidator`), only how they are shown.

### Sync badge (replaces the sync banner)
- **Why**: the old banner was a full-width strip that pushed the whole screen down while syncing. It is now a small badge in the top right corner of every tab (Dashboard, Activity, Budgets, Forecast, Settings), inside the navigation bar, so nothing moves and nothing is covered.
- **States**: Synced (green check cloud), Online (blue cloud, before the first sync), Syncing (spinner), Offline with the number of changes waiting (orange crossed-out cloud), Problem (red), and This phone (grey, when cloud sync is off). Each state has an icon and a word, so colour is never the only signal.
- **Details**: tapping the badge opens a small popover with a plain sentence about the state, how many changes are waiting, when it last synced, and a Sync now button. It stays a popover on iPhone too.
- **SyncBadgeView.swift** also has `syncStatusBadge(_:)`, a one-line modifier that adds the badge as a toolbar item. The badge is given the sync engine directly, so screen previews work without extra setup.
- VoiceOver reads "Sync status: Offline" with the hint "Shows details".

## Next-month forecast and budget plan (on-device learning)

### What it is
- A small supervised regression model that is trained on the user's own monthly totals, retrained every month, and used to predict next month's income, spending and spending per category. A budget plan is then built from the forecast. Nothing is sent anywhere. It is not a neural network: with only a handful of monthly data points a simple model is the correct choice, and every number can be checked by hand.
- The existing "This month" forecast (`ForecastEngine.swift`) is unchanged. The Forecast tab now has a "This month / Next month" switch.

### How the model is trained (`NextMonthPredictor.swift`)
1. **Data**: for each completed month (the current month is left out because it is not finished), the total spending per category and the total income. At most 24 months are used. The forecast needs spending in each of the last 3 months, the same rule as the "This month" forecast.
2. **Five candidate methods**, each predicts the next value from the earlier months of one series:
   - Weighted average of the last 3 months (weights 1, 2, 3, the default).
   - Plain average of the last 3 months.
   - Same as last month.
   - Exponential smoothing (each new month counts half).
   - Trend line: a least-squares line through the last 6 months, with the slope shrunk by 20% (ridge regularisation) so one odd month cannot throw it far, never below zero and never above 1.5 times the highest recent month.
3. **Backtesting (walk-forward validation)**: for every past month from the 4th onward, the method predicts that month using only the months before it, and the error is compared with what really happened. The score is the weighted absolute percentage error: the sum of the absolute errors divided by the sum of the real values. Months with no spending cannot cause a divide-by-zero.
4. **Choosing**: with 6 or more months of history the five methods compete and the one with the smallest backtest error is kept per category. A method must beat the default by at least 5% to replace it, so noise does not make the choice jump around. With fewer months the default is used.
5. **Learning phases** (`LearningPhase`): 3 months = basic (no accuracy yet), 4 to 5 months = early (accuracy is an early estimate from 1 or 2 tests), 6 or more months = learned (methods compete). The screen says which phase applies and why.
6. **Forecast and range**: next month's value per category. The total is the sum of the categories. The range is the value plus or minus the backtest error (at least 5%). With no backtest yet the range is the smallest and largest of the last 3 months.
7. **Accuracy shown to the user**: "Past predictions were off by about N% on average, tested on K past months". For the total it combines each category's chosen method. Because the methods were chosen using the same past months, this is slightly optimistic. It is still a fair guide, not a guarantee.

### Training every month (`NextMonthModelService.swift`)
- The trained result (chosen method, accuracy and forecast per series) is saved as JSON in `UserDefaults` together with a fingerprint: the current month plus the count and totals of the completed months. The model is retrained when the fingerprint changes, which means in a new month or when a past transaction is added, edited, deleted or synced. Otherwise the saved model is reused. This check runs whenever the app opens or comes to the foreground and when data changes.
- It does not use a background task. iOS decides when background tasks run, so they are not reliable. Training takes milliseconds, so doing it on app open is simple and dependable.
- The saved model is cleared when the user changes, on delete account, and when the history is not enough.

### Budget plan (`BudgetPlanner.swift`)
- This part is ordinary arithmetic, not learning, on purpose, so it is easy to explain.
- The user chooses a savings goal from 0% to 50% of the expected income (default 20%, remembered).
- Essentials are groceries, transport, bills and utilities, health and education. Everything else, including custom categories, is flexible.
- Essentials keep the forecast plus a 5% buffer, rounded up to 100, and are never cut.
- If expected spending is above income minus the goal, only the flexible categories are scaled down by the same factor, never below 60% of their normal level. Limits are rounded to the nearest 100 and are at least 100.
- If the goal cannot be reached even at the 60% floor, the screen says so and shows the closest achievable saving and how far short it is. If no income was recorded, there is no goal and the limits follow the forecast.
- "Apply as my budgets" asks for confirmation, then sets the monthly limit for each category in the plan (existing limits for those categories are replaced, other budgets stay). Uncategorised spending has no category, so it is skipped.

### Other changes
- `SampleData.swift` now creates 9 months so the "learned" phase can be demonstrated. Load it on a fresh install, because the sample button works once per run.
- `SyncEngine.swift` clears the saved model when the local data is wiped.
- The new tests are `NextMonthPredictorTests.swift`, `NextMonthServiceTests.swift` and `BudgetPlannerTests.swift` in `TestSource/`.

### Limits to be honest about in the report
- Personal spending is noisy, so the forecast is a guide with a range, not a promise. One-off purchases, bonuses and festivals cannot be predicted.
- Seasonal patterns (April, December) would need at least 12 months of history and are not modelled.
- The method choice is only as good as the number of past months. That is why the phases exist.

## Testing

- **TEST_CASES.md** (project root, not bundled into the app) is the test plan: how to run everything, a 10 minute smoke test, 131 manual test cases with a result column, a results summary and a defect log. Each manual case points to the automated test that covers the same logic.
- **Unit tests** are in `TestSource/` and need a Unit Testing Bundle target named `IosCWTests`. **UI tests** are in `UITestSource/` and need a UI Testing Bundle target named `IosCWUITests`. Both folders sit outside `IosCW/` so they are not bundled into the app.
- **UI test mode** (`AppContainer.swift`): launching with `-uitest` makes the app use a local sign-in, an in-memory database, fixed exchange rates and a fixed location, and switches the app lock off, so every UI test starts from a clean state and never touches real data or Firebase. `-uitest-signedin` also skips the sign-in screens. In normal use these flags are never set. The "Load sample data" step in one UI test needs a Debug build.
- The UI tests drive the iPhone tab bar, so run them on an iPhone simulator.

## Who owns the data on the phone (sign out and switching users)

- **The rule**: the data on a phone always belongs to exactly one user. It is never shown to, or uploaded for, anyone else. The owner is remembered (`syncOwnerUserID`) and checked every time someone signs in.
- **When a user signs in** (`SyncEngine.claimLocalData`, called by `AuthViewModel` before the app screens open, so the old data is never visible, not even for a moment):
  - Same user as the owner: nothing changes.
  - A different user: everything on the phone is erased (transactions, budgets, custom categories, receipt photos, the saved forecast model, the savings goal) and the default categories are put back.
  - No known owner but data exists (for example test data from an older build): it is treated as foreign and erased, so it is never uploaded into the new user's cloud account.
  - This runs whether or not Firebase is set up. Before, it only ran when cloud sync was on.
- **When a user signs out** (`SyncEngine.userSignedOut`): with cloud sync on, the phone is erased straight away, because the full copy is in the cloud and comes back at the next sign in. With cloud sync off the data is kept, because the phone holds the only copy. A different user signing in later still erases it.
- **Changes not uploaded yet**: erasing on sign out would lose them, so the sign out dialog says how many changes are waiting and offers "Sync now" or "Sign out and lose these changes". With nothing waiting it explains that the data is safe in the cloud.
- **Returning user**: when an erase happens the "last downloaded" times for every user are forgotten too. Before, they were kept, so a user who came back would only download changes made since their last visit and miss older records.
- **Delete account** uses the same erase steps, plus deleting the cloud copy and the account.

## App name and icon

- **Name**: the home screen name is "Pocketlens". It is set with the build setting `INFOPLIST_KEY_CFBundleDisplayName` in both build configurations. The project and target keep the internal name `IosCW`, so nothing else had to be renamed.
- **Icon** (`Assets.xcassets/AppIcon.appiconset`): a white receipt with a camera-viewfinder frame on a blue gradient, which says "scan a receipt". There are three 1024 by 1024 pictures: the normal one, a darker one for iOS dark mode, and a black and white one that iOS tints for its tinted icon style. iOS rounds the corners itself, so the pictures are square with no transparency. To use a different design, replace those three files and keep the same file names.
