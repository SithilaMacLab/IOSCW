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
- **SyncBannerView.swift**: shows "Offline" with the number of changes waiting, then "Syncing", then "Synced" for 3 seconds. It shows nothing when idle.
- **PersistenceController.swift**: `save(notify:)` can skip the change notification; the sync engine uses that when it only flips sync states. `wipeAll()` clears all three tables.
