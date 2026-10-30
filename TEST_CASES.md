# Pocketlens test plan and test cases

This file is not bundled into the app. It lists what to test, how to run the automated tests, and the test cases with a column to record each result.

## 1. Three kinds of testing

| Kind | What it checks | How many | How to run |
|---|---|---|---|
| **Unit tests** (automated) | The logic with no screens: receipt parser, budgets, forecast, next-month model, budget plan, currency, sync rules, CSV, delete account and more | more than 150 | Command-U |
| **UI tests** (automated) | The real screens, tapped like a user: sign-in screens, tabs, adding a transaction, sample data, forecast and budget plan, sign out | 6 | Command-U |
| **Manual test cases** (this file, section 4) | Things only a person can judge, or that need a real iPhone, Firebase or the internet. Many also point to the automated test that covers the same logic. | 137 | By hand, record the result |

## 2. How to run the automated tests

### One-time setup in Xcode (Mac)
1. **Unit tests**: File, New, Target, Unit Testing Bundle. Name `IosCWTests`, Testing System **Swift Testing**, Target to be tested `IosCW`. Delete the generated file and copy every file from `TestSource/` into the `IosCWTests` folder.
2. **UI tests**: File, New, Target, UI Testing Bundle. Name `IosCWUITests`, Target to be tested `IosCW`. Delete the generated files and copy `UITestSource/PocketlensUITests.swift` into the `IosCWUITests` folder.
3. Choose an **iPhone simulator** (for example iPhone 17 Pro) at the top. The UI tests expect the iPhone tab bar, not the iPad sidebar. Use a **Debug** build (the default), because one test uses the "Load sample data" button.

### Running
| What | How |
|---|---|
| Everything | **Command-U** (Product, Test) |
| See all tests | **Command-6** opens the Test navigator. Every test has a green tick or a red cross. |
| One test or one group | In the Test navigator click the small play button next to it. |
| Why a test failed | Click the red cross. The line that failed is highlighted with the message. Send me the test name and message. |
| Full report | **Command-9** (Report navigator), click the latest Test entry. |
| Code coverage | Product, Scheme, Edit Scheme, Test, Options, tick **Code Coverage**. Run the tests, then in the Report navigator choose Coverage. |
| From Terminal | `xcodebuild test -scheme IosCW -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |
| Only one suite | add `-only-testing:IosCWTests/ForecastEngineTests` to that command |

### How the UI tests start the app
They launch the app with `-uitest`. In this mode the app uses a local sign-in (no Firebase), a fresh in-memory database and fixed exchange rates, so each test starts from the same clean state and never touches your real data. `-uitest-signedin` skips the sign-in screens. The app lock is switched off in this mode.

If a UI test fails the first time, it is usually a timing problem or a changed label. Send me the failure message and I will adjust it.

## 3. Smoke test: the main things in about 10 minutes

Do this after every build, and before recording the demo. Use a Firebase account and a real iPhone if you can.

1. Open the app signed out. See the Welcome screen with the big illustration.
2. Create an account. You land on the Dashboard.
3. Settings, Developer, **Load sample data**.
4. Dashboard shows income, spent, a donut chart and a 6-month chart. "Where you spend" shows areas.
5. Activity: search for a shop, open a transaction, go back.
6. Add a transaction by hand. It appears at the top of Activity.
7. Budgets: the budgets from the sample data show progress bars with a status word.
8. Forecast, **This month**: expected income and spending with a range.
9. Forecast, **Next month**: "How the model learned" shows 8 months and an accuracy percentage.
10. Open **Plan next month's budget**, move the slider, tap **Apply as my budgets**, check the Budgets tab changed.
11. Switch on airplane mode. The badge at the top right says **Offline**. Add a transaction, turn airplane mode off, watch **Syncing** then **Synced**.
12. Settings, **Export CSV**, the share sheet opens.
13. Sign out. You return to the Welcome screen.

## 4. Manual test cases

Fill in the last column with **Pass**, **Fail** or **N/A** and the date. The "Automated" column shows which unit or UI test covers the same logic, so you can say it is tested twice.

Tester: ______________  Device: ______________  iOS version: ________  Build date: ________

### 4.1 Sign in and accounts

| ID | Test case | Steps | Expected result | Automated | Result |
|---|---|---|---|---|---|
| AUTH-01 | Welcome screen | Launch signed out | Big illustration, "Create account" and "Sign in" visible | UI: testWelcomeScreenShowsTheMainActions | |
| AUTH-02 | Register with a valid email | Create account, valid email, password `Password1` twice, Create account | Account created, Dashboard opens | UI: testSignedInUserSeesAllFiveTabs (signed-in state) | |
| AUTH-03 | Invalid email refused | Register with `not-an-email` | "That email address doesn't look right." and no sign-in | UI: testRegisterRejectsAnInvalidEmail, Unit: AuthValidatorTests | |
| AUTH-04 | Weak password refused | Register with `short1` | "Use at least 8 characters." | Unit: AuthValidatorTests.passwordRules | |
| AUTH-05 | Password with no number refused | Register with `onlyletters` | "Include at least one letter and one number." | Unit: AuthValidatorTests.passwordRules | |
| AUTH-06 | Passwords must match | Different confirm password | "The two passwords don't match." | Unit: AuthValidatorTests.registration | |
| AUTH-07 | Live checklist | Type a password slowly | Each of the 3 rows turns into a green tick as it is met | | |
| AUTH-08 | Show and hide password | Tap the eye icon | Password shows, then hides, field keeps focus | | |
| AUTH-09 | Keyboard flow | Press Return on each field | Moves to the next field, last field submits | | |
| AUTH-10 | Email already used | Register an email that exists (Firebase) | "An account with that email already exists. Try signing in." | | |
| AUTH-11 | Sign in | Sign in with the right details | Dashboard opens | | |
| AUTH-12 | Wrong password | Sign in with a wrong password (Firebase) | "The email or password is incorrect." | | |
| AUTH-13 | Forgot password | Sign in, Forgot password, enter email | Confirmation message and a reset email arrives (Firebase) | | |
| AUTH-14 | Sign out | Settings, Sign out, confirm | Welcome screen appears. With Firebase on, the data is removed from the phone. | UI: testSigningOutReturnsToTheWelcomeScreen, Unit: AuthSessionTests.signOutClears | |
| AUTH-15 | Firebase is really connected | Settings | "Sign-in service: Firebase". The user shows in Firebase, Authentication, Users | | |

### 4.2 App lock (real iPhone)

| ID | Test case | Steps | Expected result | Automated | Result |
|---|---|---|---|---|---|
| LOCK-01 | Turn lock on | Settings, switch on Lock with Face ID | Face ID prompt, then the switch stays on | | |
| LOCK-02 | Locked on reopen | Close the app fully, open it | Lock screen, Face ID unlocks it | | |
| LOCK-03 | Cancel | Cancel the Face ID prompt | Stays locked with no error. Passcode fallback works. | | |
| LOCK-04 | Privacy cover | With lock on, open the app switcher | App preview is hidden | | |
| LOCK-05 | Turn lock off | Switch it off and confirm | App opens without the lock | | |

### 4.3 Transactions

| ID | Test case | Steps | Expected result | Automated | Result |
|---|---|---|---|---|---|
| TXN-01 | Add an expense | Activity, Add transaction, Add manually, amount 1250, merchant, Save | New row at the top with a minus amount | UI: testAddingATransactionShowsItInActivity | |
| TXN-02 | Zero amount refused | Save with amount 0 or empty | "Enter an amount greater than zero." | | |
| TXN-03 | Add income | Choose Income, amount 150000, Save | Green amount with a plus sign | | |
| TXN-04 | Edit | Tap a row, change the amount, Save | Row and Dashboard totals update | | |
| TXN-05 | Delete | Swipe a row, Delete | Row disappears, Dashboard totals update | | |
| TXN-06 | Foreign currency | Choose USD, amount 10 | Rate and the LKR amount shown, saved with the transaction | Unit: CurrencyTests | |
| TXN-07 | Rate offline, cached | Airplane mode, choose USD | Last known rate used with a note that it is saved | Unit: CurrencyTests.staleCacheUsedOffline | |
| TXN-08 | Rate offline, nothing cached | New install offline, choose USD | A box to enter the rate yourself | Unit: CurrencyTests.nothingAvailable | |
| TXN-09 | Amount saved in LKR | Add 10 USD at rate 300 | LKR amount is 3,000 | Unit: SyncMapperTests.expenseRoundTrip | |

### 4.4 Search, filter and sort

| ID | Test case | Steps | Expected result | Automated | Result |
|---|---|---|---|---|---|
| ACT-01 | Search | Type part of a merchant, note or category | Only matching rows show | | |
| ACT-02 | Filter | Open Filter, pick type, category and dates | List matches the filter, filter icon is filled | | |
| ACT-03 | Sort | Sort menu: newest, oldest, biggest | Order changes accordingly | | |
| ACT-04 | No matches | Search for gibberish | "No matches" with a clear button that restores the list | | |

### 4.5 Categories

| ID | Test case | Steps | Expected result | Automated | Result |
|---|---|---|---|---|---|
| CAT-01 | Add | Settings, Categories, plus, name, icon, colour, Save | New category appears and can be used in a transaction | | |
| CAT-02 | Duplicate name | Add a category with an existing name (any letter case) | "A category with that name already exists." | | |
| CAT-03 | Empty name | Save with no name | "Please enter a category name." | | |
| CAT-04 | Edit | Change name and colour | All its transactions show the new look | | |
| CAT-05 | Default is protected | Try to delete a default category | "Default categories can't be deleted." | | |
| CAT-06 | Delete a custom one | Delete a custom category that has transactions | Its transactions become Uncategorised, its budget is removed | | |

### 4.6 Budgets

| ID | Test case | Steps | Expected result | Automated | Result |
|---|---|---|---|---|---|
| BUD-01 | Add a budget | Budgets, plus, category, limit | Row with a progress bar and amount left | | |
| BUD-02 | Status words | Spend to 50%, 85% and 110% of a limit | On track, Near limit, Over budget, each with an icon | Unit: BudgetTests.statusThresholds | |
| BUD-03 | One budget per category | Set a limit twice for the same category | The existing one is updated, not duplicated | Unit: BudgetTests.limitsAreUpdatedNotDuplicated | |
| BUD-04 | Zero limit refused | Save a limit of 0 | "Enter a monthly limit greater than zero." | Unit: BudgetTests.invalidLimit | |
| BUD-05 | Only this month counts | Add an expense dated last month | The budget progress does not change | Unit: BudgetTests.spentCountsTheRightTransactions | |
| BUD-06 | Delete | Swipe a budget, Delete | Budget removed, category and transactions stay | | |

### 4.7 Dashboard

| ID | Test case | Steps | Expected result | Automated | Result |
|---|---|---|---|---|---|
| DASH-01 | Totals | Compare Income, Spent, Balance with Activity | Numbers match the month's transactions | | |
| DASH-02 | Donut chart | Open Dashboard | Donut by category with a list of amounts | UI: testSampleDataFillsTheDashboard... | |
| DASH-03 | Six-month chart | Scroll down | Bars for income and expenses per month | | |
| DASH-04 | Empty state | New account, no data | "Nothing to show yet" message | | |
| DASH-05 | Predicted and actual card | With 3 months of data | Expected spending and a progress bar | | |
| DASH-06 | Plus button | Dashboard, tap the plus at the top right | Menu with Add expense and Add income | | |
| DASH-07 | Add income from the Dashboard | Plus, Add income, amount, Save | Form opens as Income with Salary chosen. After Save the Income total on the Dashboard goes up. | Unit: ExpenseFormTypeTests.incomeButton | |
| DASH-08 | Add expense from the Dashboard | Plus, Add expense, amount, Save | Form opens as Expense. After Save the Spent total goes up. | Unit: ExpenseFormTypeTests.expenseButton | |
| DASH-09 | Empty Dashboard buttons | New account with no data | "Add expense" and "Add income" buttons under the message | | |

### 4.8 Receipt scanning

| ID | Test case | Steps | Expected result | Automated | Result |
|---|---|---|---|---|---|
| SCAN-01 | Receipt from a photo | Add transaction, Choose a receipt photo | Review form opens with merchant, date, total and category filled | | |
| SCAN-02 | Total is right | Use a receipt with Sub Total, Total and Cash | The Total (not subtotal or cash) is chosen | Unit: ReceiptParserTests.grandTotalWins, plainTotal | |
| SCAN-03 | Date format | Receipt dated 05/10/2026 | 5 October 2026 (day first) | Unit: ReceiptParserTests.dayFirstDate | |
| SCAN-04 | Merchant | Receipt with the shop name at the top | Name in Title Case, phone and invoice lines skipped | Unit: ReceiptParserTests.merchantSkipsNoise | |
| SCAN-05 | Currency | Receipt with Rs, USD or $ | Right currency chosen | Unit: ReceiptParserTests.currencyDetection | |
| SCAN-06 | Doubtful fields | Use a blurry receipt | Orange rows with an icon and "Check the ..." text | Unit: ReceiptParserTests.ocrConfidenceMatters | |
| SCAN-07 | Unreadable image | Choose a photo with no text | Message and the chance to enter the transaction by hand | | |
| SCAN-08 | Camera scan | Real iPhone, Scan a receipt | Edges found, review form opens | | |
| SCAN-09 | Category suggestion | Scan a Keells receipt | Groceries suggested | Unit: CategorySuggesterTests | |
| SCAN-10 | Learns from you | Change the suggested category, Save, scan the same shop again | The corrected category is suggested | Unit: CategorySuggesterTests.merchantMemory | |
| SCAN-11 | Photo is kept on the phone | Save, reopen the transaction | Receipt photo shows. It is not in Firebase. | | |
| SCAN-12 | Lines on the receipt | Receipt where TOTAL and the amount are far apart | They are joined into one row | Unit: ReceiptLayoutTests | |

### 4.9 Places and the map

| ID | Test case | Steps | Expected result | Automated | Result |
|---|---|---|---|---|---|
| LOC-01 | Place on scan | Scan a receipt, allow location | Area name (for example Bambalapitiya, Colombo) in the form | | |
| LOC-02 | Permission denied | Turn location off for the app, scan | Saved without a place, message and Open Settings button | | |
| LOC-03 | Add place by hand | New manual transaction, Add current place | Place saved, Remove place works | | |
| LOC-04 | Ranking | Dashboard, Where you spend, See the map | Areas ranked by total, numbered circles | Unit: SpendingAreaTests.ranking | |
| LOC-05 | Offline | Airplane mode, open the map screen | The ranked list still works | | |
| LOC-06 | Period | Switch this month, 3 months, all time | List and map change | | |

### 4.10 Forecast for this month

| ID | Test case | Steps | Expected result | Automated | Result |
|---|---|---|---|---|---|
| FC-01 | Not enough data | Account with under 3 months of expenses | "Not enough data yet" with how many months you have | Unit: ForecastEngineTests.notEnoughData | |
| FC-02 | Numbers | Sample data, Forecast, This month | Income, spending, left over, each with a range | Unit: ForecastEngineTests.expectedSpending | |
| FC-03 | Salary not doubled | Salary paid on day 1 | Expected income equals the salary | Unit: ForecastEngineTests.incomeIsNotDoubled | |
| FC-04 | Last day of month | On the 31st | Forecast equals what was recorded | Unit: ForecastEngineTests.lastDayOfMonth | |
| FC-05 | Early warning | Spend more than income, or pass a budget | Warning with an icon and text | | |
| FC-06 | Chart | Open the chart card | Last 3 months and this month, solid and pale part | | |

### 4.11 Next-month forecast (on-device learning)

| ID | Test case | Steps | Expected result | Automated | Result |
|---|---|---|---|---|---|
| NM-01 | Shows | Forecast, Next month (sample data) | Expected income, spending, left over and categories for next month | UI: testSampleDataFillsTheDashboard... | |
| NM-02 | Learning phase | Compare accounts with 3, 5 and 8 months | Text changes: basic, early estimate, learned | Unit: PredictorModelTests.phases | |
| NM-03 | Best method chosen | Account with 8 months of rising spending | A category shows "Trend line" as its method | Unit: PredictorModelTests.risingSeriesPicksTrend | |
| NM-04 | Accuracy shown | 4 or more months | "Off by about N% on average, tested on K months" | Unit: NextMonthTrainingTests.categoriesCompete | |
| NM-05 | Current month ignored | Add a huge transaction this month | Next month forecast does not change | Unit: NextMonthTrainingTests.currentMonthIgnored | |
| NM-06 | Saved model reused | Reopen the app in the same month | "Last trained" date does not change | Unit: NextMonthServiceTests.savedModelIsReused | |
| NM-07 | Retrains on a new month | Change the phone date to next month, reopen | Last trained date updates, one more month of history | Unit: NextMonthServiceTests.newMonthRetrains | |
| NM-08 | Retrains on a past edit | Edit an old transaction, reopen | Last trained date updates | Unit: NextMonthServiceTests.editingHistoryRetrains | |
| NM-09 | Tiny categories hidden | Category with almost no spending | Not listed | Unit: NextMonthTrainingTests.tinyCategoriesHidden | |

### 4.12 Budget plan

| ID | Test case | Steps | Expected result | Automated | Result |
|---|---|---|---|---|---|
| PLAN-01 | Open the plan | Next month, Plan next month's budget | Savings goal, flexible and essential lines | UI: testSampleDataFillsTheDashboard... | |
| PLAN-02 | Slider | Move the goal from 0 to 50% | Flexible limits shrink, essentials stay the same | Unit: BudgetPlannerTests.tighterGoalTrimsFlexible | |
| PLAN-03 | Essentials never cut | Goal at 50% | Groceries, transport, bills, health, education equal forecast plus 5% | Unit: BudgetPlannerTests.impossibleGoal | |
| PLAN-04 | Goal too high | Goal at 50% with high spending | Warning with the closest possible saving | Unit: BudgetPlannerTests.impossibleGoal | |
| PLAN-05 | No income | Account with no income | No goal, limits follow the forecast | Unit: BudgetPlannerTests.noIncome | |
| PLAN-06 | Apply | Apply as my budgets, confirm | "Budgets updated", Budgets tab shows the new limits | UI: testSampleDataFillsTheDashboard..., Unit: BudgetPlanViewModelTests.apply | |
| PLAN-07 | Apply twice | Change the goal, apply again | Limits replaced, no duplicate budgets | Unit: BudgetPlanViewModelTests.applyTwice | |
| PLAN-08 | Goal remembered | Leave and reopen the plan | Slider is where you left it | Unit: BudgetPlanViewModelTests.rateIsRemembered | |

### 4.13 Offline and sync (needs Firebase)

| ID | Test case | Steps | Expected result | Automated | Result |
|---|---|---|---|---|---|
| SYNC-01 | Upload | Online, add a transaction | Badge shows Syncing then Synced. It appears in Firestore, users, your id, expenses. | Unit: SyncEngineTests.pushesPendingChanges | |
| SYNC-02 | Offline queue | Airplane mode, add 2 transactions | Badge: Offline with 2. App keeps working. | Unit: SyncEngineTests.offlineQueue | |
| SYNC-03 | Back online | Turn airplane mode off | Changes upload by themselves, badge Synced | Unit: SyncEngineTests.offlineQueue | |
| SYNC-04 | Badge details | Tap the badge | Popover with status, waiting count, last sync, Sync now | | |
| SYNC-05 | Newer cloud change wins | Edit on another phone, sync here | This phone shows the newer value | Unit: SyncEngineTests.newerCloudChangeWins | |
| SYNC-06 | Old cloud change ignored | | Local newer copy is kept | Unit: SyncEngineTests.olderCloudChangeIgnored | |
| SYNC-07 | Deletion syncs | Delete on one phone, sync the other | It disappears on both | Unit: SyncEngineTests.cloudDeletionRemovesLocalCopy, localDeletionUploadsTombstone | |
| SYNC-08 | Failure | Break the rules or network mid-sync | Badge Problem, changes stay pending and retry | Unit: SyncEngineTests.failureKeepsChangesPending | |
| SYNC-09 | Different user | Sign out, sign in as another user | Previous user's data is gone | Unit: SyncEngineTests.differentUserWipesLocalData | |
| SYNC-10 | Same user | Sign out and in again as the same user | Data is kept | Unit: SyncEngineTests.sameUserKeepsData | |
| SYNC-11 | Default categories | Sign in on a second phone | No duplicate default categories | Unit: SyncRecordTests.defaultCategoriesMatchAcrossDevices | |
| SYNC-12 | Not signed in | Sign out and add data offline | Nothing is uploaded | Unit: SyncEngineTests.signedOutDoesNotSync | |
| SYNC-13 | Sign out erases this phone | User A with data signs out (Firebase on) | Welcome screen. Signing in as B shows an empty app with only the default categories. | Unit: SyncEngineTests.signOutErasesWhenCloudIsOn | |
| SYNC-14 | New user never sees old data | User A signs out, user B registers on the same phone | B sees no transactions, budgets or custom categories, not even for a moment | Unit: SyncEngineTests.differentUserWipesLocalData, AuthSessionTests.claimsBeforeOpening | |
| SYNC-15 | Old user gets everything back | After B, sign out and sign A in again | All of A's data downloads again, including old transactions | Unit: SyncEngineTests.erasingForgetsPullHistory | |
| SYNC-16 | Warning before data is lost | Offline, add a transaction, Settings, Sign out | Dialog says N changes are not uploaded and offers Sync now or Sign out and lose these changes | | |
| SYNC-17 | Leftover data is not adopted | Phone with old test data, new Firebase user signs in | Old data is erased and nothing is uploaded to the new account | Unit: SyncEngineTests.ownerlessDataIsErased | |
| SYNC-18 | Cloud off, different user | No Firebase, user A signs out, user B signs in | B sees no data of A | Unit: SyncEngineTests.localOnlyDifferentUser | |

### 4.14 Widget

| ID | Test case | Steps | Expected result | Automated | Result |
|---|---|---|---|---|---|
| WID-01 | Add widget | Home Screen, plus, Pocketlens | Small and medium widgets available, plus Lock Screen ones | | |
| WID-02 | Numbers | Compare with the Dashboard | Spent and budget status match | Unit: WidgetSnapshotTests.totals | |
| WID-03 | Updates | Add a transaction, look again | Widget updates within a short time | | |
| WID-04 | Signed out | Sign out | Widget says "Open Pocketlens to see your spending." | | |
| WID-05 | Phone locked | Lock the phone | Amounts are hidden on the Lock Screen widget | | |

### 4.15 Export and delete

| ID | Test case | Steps | Expected result | Automated | Result |
|---|---|---|---|---|---|
| EXP-01 | Export | Settings, Export CSV | Share sheet with a file named Pocketlens-transactions-DATE.csv | Unit: CSVExporterTests.fileName | |
| EXP-02 | Opens in Excel | Send it to yourself and open it | One row per transaction, names and amounts correct | Unit: CSVExporterTests.singleRow | |
| EXP-03 | Formula safety | Add a merchant called `=SUM(A1)`, export | Cell shows text, not a formula | Unit: CSVExporterTests.formulaGuard | |
| EXP-04 | Nothing to export | New account | "There are no transactions to export yet." | | |
| DEL-01 | Cancel | Delete account, then Cancel | Nothing changes | | |
| DEL-02 | Wrong password | Enter a wrong password | Error, nothing deleted | Unit: AccountDeletionTests.wrongPassword | |
| DEL-03 | Offline | Airplane mode, try to delete | Asks you to connect first | Unit: AccountDeletionTests.offline | |
| DEL-04 | Delete everything | Delete with the right password | Back to Welcome. The user and the data are gone from Firebase. Signing in again fails. | Unit: AccountDeletionTests.fullDeletion | |
| DEL-05 | Cloud failure | Make the cloud step fail | Error shown, account and data kept | Unit: AccountDeletionTests.cloudFailure | |

### 4.16 Look, layout and accessibility

| ID | Test case | Steps | Expected result | Automated | Result |
|---|---|---|---|---|---|
| UI-01 | Five tabs | Open each tab | Dashboard, Activity, Budgets, Forecast, Settings, sync badge at the top right of each | UI: testSignedInUserSeesAllFiveTabs | |
| UI-02 | Dark mode | Switch to dark mode | Every screen readable, illustrations look right | | |
| UI-03 | Largest text size | iOS Settings, Accessibility, Larger Text, maximum | Rows stack vertically, nothing is cut off | | |
| UI-04 | VoiceOver | Turn on VoiceOver, go through Activity | Each row reads as a sentence, charts have a description | | |
| UI-05 | iPad | Run on an iPad simulator | Sidebar instead of the tab bar, Activity shows list and detail | | |
| UI-06 | Landscape | Rotate the phone | Layouts still work | | |
| UI-07 | Touch size | Try every button with a thumb | Nothing is too small to tap | | |
| UI-08 | Warnings not only colour | Look at Over budget, Offline, Problem | Each has an icon and a word | | |
| UI-09 | Appearance setting | Settings, Appearance, choose Light, then Dark, then System | Whole app switches at once, including sheets and the sign-in screens. System follows the phone. | Unit: AppearanceModeTests | |
| UI-10 | Amounts are never cut off | Dashboard with an amount of 150,000 or more, on the smallest iPhone and at a large text size | Income, Spent and Balance show the whole amount (it may shrink) with no "..." | | |

## 5. Results summary

| Area | Cases | Pass | Fail | N/A |
|---|---|---|---|---|
| Sign in and accounts | 15 | | | |
| App lock | 5 | | | |
| Transactions | 9 | | | |
| Search, filter, sort | 4 | | | |
| Categories | 6 | | | |
| Budgets | 6 | | | |
| Dashboard | 9 | | | |
| Receipt scanning | 12 | | | |
| Places and map | 6 | | | |
| Forecast, this month | 6 | | | |
| Next-month forecast | 9 | | | |
| Budget plan | 8 | | | |
| Sync | 18 | | | |
| Widget | 5 | | | |
| Export and delete | 9 | | | |
| Look and accessibility | 10 | | | |
| **Total** | **137** | | | |

Automated: unit tests passed ____ of ____, UI tests passed ____ of 6, on ________ (date).

## 6. Defect log

| No. | Test case | What happened | What should have happened | Severity | Status |
|---|---|---|---|---|---|
| 1 | | | | | |
| 2 | | | | | |
