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
- **AppContainer.swift**: now also holds the auth service.
