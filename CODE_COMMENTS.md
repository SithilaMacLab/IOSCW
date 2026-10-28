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

## View models and screens

- **DashboardViewModel.swift**: `TrendPoint` is one bar in the income-vs-expenses chart; `kind` is "Income" or "Expenses".
- **BudgetsViewModel.swift**: `BudgetItem` is a budget plus what has been spent this month. Rows are sorted with the most urgent first. `categoriesWithoutBudget` feeds the add-budget picker.
- **ExpenseFormViewModel.swift** and **CategoriesViewModel.swift**: `save()` returns true when it worked, so the form can close.
- **ActivityViewModel.swift**: the list shows transactions filtered first, then sorted.
- **ActivityFilterView.swift**: works on a copy of the filter and only writes back when Apply is tapped.
- **CategoriesView.swift**: pushed from Settings, so it has no NavigationStack of its own.
- **CategoryFormView.swift**: colour and icon are picked from fixed grids.
- **DashboardView.swift**: the category legend shows icon, name and amount, so nothing depends on colour alone.
- **SettingsView.swift**: the "Load sample data" button is in debug builds only.
- **ContentView.swift**: the iPhone tab bar. The iPad sidebar (NavigationSplitView) comes in the final polish stage.
