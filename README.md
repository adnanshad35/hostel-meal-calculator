# HostelMate

**A shared meal and expense manager for hostels and messes.**

HostelMate replaces the handwritten meal register and the end-of-month calculator. Members record their meals and what they spend; the app works out the meal rate and shows each person the one amount they pay or collect. Everyone in the hostel sees the same figures, and every change is on record, so there is nothing to argue about.

It is built with Flutter and Firebase and runs on Android and in the browser. There is no server code: every permission is enforced by Firestore Security Rules.

**[Download for Android](https://github.com/adnanshad35/hostel-meal-calculator/releases/latest/download/HostelMate.apk)** (64-bit, most phones) · **[32-bit for older phones](https://github.com/adnanshad35/hostel-meal-calculator/releases/latest/download/HostelMate-32bit.apk)** · **[Open the web version](https://hostelmate.web.app/app/)** · **[Website](https://hostelmate.web.app)**

Current version: **1.9.0**

---

## Contents

- [The problem it solves](#the-problem-it-solves)
- [Who uses it](#who-uses-it)
- [Features](#features)
- [Balance Options](#balance-options)
- [Accountability and the month lock](#accountability-and-the-month-lock)
- [How the monthly calculation works](#how-the-monthly-calculation-works)
- [Hostel activation](#hostel-activation)
- [Architecture](#architecture)
- [Data model](#data-model)
- [Security model](#security-model)
- [Project structure](#project-structure)
- [Getting started](#getting-started)
- [Testing](#testing)
- [Releasing and deploying](#releasing-and-deploying)
- [Known limitations](#known-limitations)
- [Roadmap](#roadmap)
- [Developer](#developer)

---

## The problem it solves

In a shared hostel, one person usually keeps a notebook of who ate how many meals and who paid for groceries. At the end of the month that person adds everything up by hand, divides the cost by the meals, and tells each member what they owe. The process is slow, mistakes are common, and members have to trust figures they cannot check.

HostelMate keeps the same records in one shared place:

- each member enters their own meals and expenses, so the data is not one person's job;
- days a member forgets to enter are filled in from their meal plan;
- the calculation is automatic and identical for everyone;
- every change, by a member or an admin, is recorded where the whole hostel can see it.

## Who uses it

| Role | Who they are | What they can do |
|---|---|---|
| **Member** | Anyone living in the hostel | Record their own meals and expenses (if the admins allow it), set their meal plan, view the hostel's records, calculation and Accountability |
| **Hostel admin** | One or more members who run the hostel | Everything a member can do, plus manage members and duty dates, record entries for others, set the month's minimum meals and shop due, change Admin Settings, send announcements, activate the hostel |
| **Super admin** | The app's owner (one account) | Oversee every hostel and user, manage vouchers, payments and app updates, read feature requests, pause the app, send app-wide notices |

Hostels often include people who will never install an app. An admin can add them **by name only**; their meals and expenses are recorded by the admin and they are included in every calculation. If they later join with an account, the admin can link the two and their records in open months move across.

## Features

The phone app has four tabs along the bottom: **Home**, **Meals**, **Expenses** and **Balance**. The website's [Guide](https://hostelmate.web.app/#guide) walks a new user from sign-up to settings.

### First steps

- **Welcome**: the HostelMate logo, what the app does in three lines, and **Create New Account** or **Sign In**
- **Create Account**: name, email, phone and password, with a checklist that turns green as each password rule is met
- **Verify Email**: the app checks by itself every few seconds and when you come back from your email app, so it moves on as soon as the link is opened. **Resend** waits 60 seconds between emails, and a tip says where the email comes from and to check Spam
- **Join a Hostel** (the main choice) or **Create a Hostel**
- **Joining** shows the hostel's name as soon as the 6-character code is typed, before you join
- **Creating** ends on a page with the **Hostel Code** in large letters, with **Copy** and **Share**; Share sends the app link, the steps and the code

### Home

- The hostel's name, who is on duty today, and the **Hostel Details** button
- The month's meal rate, with your own expense and meal count
- **For Today**: how many lunches and dinners the hostel is having (tap either to see who is eating)
- One-tap **+** to add a meal or an expense, shown only when you are allowed to add them
- A bell for announcements, app notices and members who will be away

### Meals

- Record lunch and dinner for a day, in steps of one (halves can be typed)
- **Meal plans**: your usual lunch and dinner from a date; empty days are counted from the plan and marked **Auto**
- One page: the month at the top, **My Meals** and **Total Meals**, a calendar, and the chosen day's table
- In the table your own row comes first; tap a row with a pencil to change it. Days still to come cannot be picked
- Admins can record or correct meals for any member, including members without the app
- **Chef**: beside the title of Add Meal, admins see **Chef ✓**. Tapping it turns **Lunch** or **Dinner** off for everyone for that day, with **Cancel** and **Save**. An off meal shows in red, and the day turns back on by itself the next day. Members' usual meals are kept, so turning a meal back on restores them

### Expenses

- Two ways to add one, one at a time; switching starts the other empty:
  - **Simple**: an expense name and an amount, with a built-in calculator
  - **Itemwise**: rows of **Item | Qty | Price** (for example Rice | 5 kg | ৳350). **Add Item** adds a row, the total adds up by itself, and the name is made from the items (*Rice, Oil, Onion*). The phone remembers the mode used last
- An itemwise expense is saved as a normal expense: the items are written into its description, one per line, so every app version reads it
- Who paid: admins can record an expense for any member
- The same one-page layout: **My Expenses**, **Total Expenses**, a calendar and the day's table
- Members change their own entries; admins can change or delete any entry

### Balance

- The top card: the meal rate, total meals, total cost, and the figures switched on in Balance Options, with the change from last month. Admins see **+ More Options** while any option is off
- Every member's balance, **Pay** or **Collect**; tapping a member shows their meals, meal cost and spending
- The **Members** card's share menu: **Copy Balances**, **Copy Full Table** (WhatsApp-ready text) and **Share as Picture**: a branded image with the hostel's name, the month, the day it was made, and each member's **Meals | Meal Cost | Paid | Balance**
- **Best Manager**, **Fixed Costs**, **Meal + Fixed Cost** and **Month Trend** cards when switched on (see [Balance Options](#balance-options))
- Earlier months can be opened to review their figures
- Minimum meals and shop due can be entered from the 25th of the month to the 5th of the next, unless an admin turns on **Min Meals & Shop Due Any Day**

### Hostel Details

- **Activation**: whether the hostel is active and for how long; admins tap it to renew
- **Hostel Code**: tap it to copy, then send it to new members, who enter it under **Join a Hostel**
- **Accountability**: the hostel's change history (see [below](#accountability-and-the-month-lock)), with a red dot when someone else changed something since you last looked
- **Members**, with **Admin** and **No App** tags and each member's phone number. Admins can **Remove** a member; their records always stay
- **Admin Settings** (admins only): see below
- **Leave Hostel**: your past records stay; the only admin must first make another member admin

### Admin Settings

Organised in groups:

| Group | Settings |
|---|---|
| **Members Who Left** | How each member who left this month counts: **Remove All**, **Keep Actual** or **Keep Normal** (shown only when someone left) |
| **Members** | **Member Settings**: Allow New Members, Add Member Without App, Duty Roster, Remove All Limits. **Member Permissions**: Add Meals, Add Expenses, Edit Their Entries |
| **Balance** | **Balance Options** (see [below](#balance-options)) |
| **Hostel** | Send Announcement |
| **Danger Zone** | Reset This Month |

A hostel's name is set when it is created and cannot be changed. The **Duty Roster** sets which member looks after the hostel on which dates, with clash checks; drag a member to swap periods.

### Profile

- An account needs a name (it cannot be changed later), an email, an 11-digit phone number starting with 01, and a password of at least 6 characters with an upper-case letter, a lower-case letter, a digit and a symbol
- Three wrong passwords in a row stop sign-in on that device for 5 minutes
- **Set Nickname**: one word of up to 12 letters, shown inside the hostel instead of the name
- **Change Password** by email
- **HostelMate Guide**: a one-page guide to every part of the app, with a menu that jumps to each section
- **Check for Updates** (Android): finds a new version and installs it inside the app
- **App and Developer**: what HostelMate is, the web version, the website, the developer's contacts, and **Request a Feature**, which sends a message straight to the super admin

### Notifications

- **Inside a hostel:** announcements written by admins (up to 50 words) and meal plan periods a member chose to announce
- **App-wide:** notices from the super admin, shown as a pop-up and kept in a list
- Anyone can remove a notice from their own list once it is a day old
- An unread count appears on the bell

Notifications are in-app. They appear while the app is open and the next time it is opened; they are not pushed to a closed phone. Changes to meals and expenses are not sent as notifications; they are in Accountability.

### Super admin panel

The super admin's account opens directly into an administration panel, with a desktop layout on wide screens:

- **Overview**: payments waiting (at the top when there are any), hostels, users, and **App Controls**: Maintenance, App Update and App Notices
- **Users**: every account, searchable and sortable
- **Hostels**: every hostel with its status; set its remaining days, switch editing or access off, open its Accountability, or delete it
- **Payments**: publish the bKash number and instructions, approve or reject reported payments
- **Vouchers**: create voucher codes and switch them off
- **Requests**: feature requests sent from the app

### Updates and the web version

- The same app runs at [hostelmate.web.app/app](https://hostelmate.web.app/app/), with the same accounts, data and phone layout (a phone-width column on a wide window)
- The super admin sets the **Latest Version**, an optional **Minimum Version**, and **What's New** under App Update
- On launch the Android app checks that setting. A version below the minimum must update before continuing; otherwise the update is optional. The APK downloads and installs inside the app, with a progress bar
- After updating, the app shows **What's New** once

## Balance Options

Admins choose which figures the Balance page uses, in **Admin Settings → Balance Options** or with **+ More Options** on the Balance page.

| Option | Default | What it does |
|---|---|---|
| **Min Meals** | On | The month's minimum meals count in the calculation |
| **Shop Due** | On | The month's shop due counts in the total cost |
| **Initial Share** | Off | Money collected at the start of the month for its food (rice, oil…). The admin enters a total and the contributors; it splits equally by default. Each part counts in that member's **Paid** and shows as *Initial Share* in their expenses; the whole amount counts in the meal rate |
| **Fixed Costs** | Off | Admins set each member's rent and the shared bills (Wi-Fi, electricity, chef…), split equally among current members. A **Fixed Costs** card shows each member's **Rent \| Bills \| Total**; the figures carry forward to the next month until changed |
| **Meal + Fixed Cost** | Off | Shown with Fixed Costs on: each member's meal balance and fixed cost together, as **Pay** or **Collect** |
| **Best Manager** | Off | The finished duty turn (3 days or more) with the cheapest meal rate, against the month's average, without Initial Share and Shop Due. Tap it for the full ranking |
| **Month Trend** | On | This month against last month, day by day, as **Rate**, **Meals** or **Cost** |

Rules that keep earlier months safe:

- **Min Meals**, **Shop Due** and **Fixed Costs** are remembered by month: a switch applies from the current month on, and earlier months keep their figures. Saved values are kept when a figure is switched off.
- **Fixed Costs** only uses rent and bills saved **since the month it was switched on**, so figures entered long ago never come back by themselves.
- **Initial Share** parts already added still count when the option is off, because that money was really collected; only the box disappears.
- New options are saved under the hostel's `options` field, which older app versions do not overwrite.

## Accountability and the month lock

Admins can record and correct entries for anyone, so the app makes every change visible and limits how far back changes can go.

**Accountability** (Hostel Details → Accountability) records who did what and when, with the old and new figures, such as *Lunch 1 → 2*:

- **Meals**: meals added or changed, meal plans changed
- **Expenses**: expenses added, changed or deleted
- **Admin**: minimum meals and shop due, month resets, members removed, admins made or removed, and hostel activation

Added is shown in green, changed in gold, and deleted or removed in red. Each record is written in the same batch as the change itself, and the security rules allow records to be added but never changed or deleted, by anyone.

**Edited marks.** A meal or expense changed more than one minute after it was first saved is marked **Edited** in its table, whoever changed it.

**Month lock.** A month's meals and expenses can be added, changed or deleted until the 7th of the next month (Bangladesh time), by everyone, admins included. After that:

- **Last month** is closed: every detail stays visible, but nothing can change.
- **Older months** keep only their summary: meal rate, total meals, total expense and each member's figures.

The lock is enforced by the security rules using the server's clock, not just hidden in the app.

## How the monthly calculation works

```text
Total cost       = Expenses paid by members + Shop due
Charged meals    = max(Meals eaten, Minimum meals)      for each member
Meal rate        = Total cost ÷ Sum of charged meals

Meal expense     = Meal rate × Charged meals            for each member
Balance          = Amount the member paid − Meal expense
```

Meals eaten include the days filled in from meal plans. A **positive** balance means the member collects money; a **negative** balance means the member pays. Results are rounded to a whole taka once, at the end.

### Worked example

Two members, no minimum, and a shop due of ৳500:

| | Meals eaten | Paid for groceries |
|---|---|---|
| Adnan | 30 | ৳2,400 |
| Rahim | 20 | ৳600 |

```text
Total cost = 2,400 + 600 + 500 = ৳3,500
Meal rate  = 3,500 ÷ 50 meals  = ৳70 per meal

Adnan: paid 2,400 − (30 × 70) = +300   → collects ৳300
Rahim: paid   600 − (20 × 70) = −800   → pays ৳800
```

Together they owe ৳500, which is exactly the shop due.

### Rules worth knowing

- **Former members.** Someone who left but has meals or expenses in a month still appears in that month's calculation under their saved name.
- **Minimum meals and shop due** are set per month and start at zero each month, and count only while switched on in Balance Options.
- **Initial Share** parts are ordinary expenses paid by each contributor, so they need nothing special in the calculation.
- **Meal Off** days count as no meal for anyone; meal plans and saved meals for that day are kept for when the meal is turned back on.
- **Rent and shared bills** (Fixed Costs) are shown beside the meal balance, never inside it.

## Hostel activation

A hostel is **active** for a number of days. When the period ends it becomes **read-only**: every record stays visible, but meals, expenses, and monthly settings cannot be added or changed until it is activated again.

Every new hostel starts with **7 free days**, with no voucher needed. After that, a hostel admin activates or extends the hostel from Hostel Details → Activation with a **voucher**: a code issued by the super admin. Each hostel can use a given voucher once. Extending an active hostel adds days to the end of its period. Every activation is recorded in Accountability.

**Paying with bKash**: an admin reports the transaction ID, and the super admin approves or rejects it in the Payments tab.

## Architecture

```text
┌──────────────────────────────────────────────┐
│  Screens (lib/screens)                       │  One file per screen
├──────────────────────────────────────────────┤
│  Widgets (lib/widgets)                       │  Shared UI: calendar, chart…
├──────────────────────────────────────────────┤
│  Services (lib/services)                     │  Data access + business logic
│   ├─ pure logic: calculator, meal plans,     │  No Firebase; unit tested
│   │   duty roster, month lock, edit marks    │
│   └─ Firestore access: members, activity…    │
├──────────────────────────────────────────────┤
│  Firebase Authentication · Cloud Firestore   │
│  Firestore Security Rules (firestore.rules)  │  All authorization
│  Firebase Hosting                            │  Website + web app
└──────────────────────────────────────────────┘
```

Design decisions:

- **No backend code.** The app talks to Firestore directly. Anything a user must not be able to do is refused by the security rules, not hidden in the interface.
- **Money logic is pure Dart.** `MonthlyCalculator`, `MealPlans` and `DutyRoster` take plain values and return plain values, so they are tested without a database.
- **One month at a time.** Screens query a single month of meals and expenses (`MonthRecords`), so the cost of opening a screen does not grow with the hostel's history.
- **Live data.** Screens listen to Firestore, so a meal entered on one phone appears on the others without refreshing, and cached data is shown when offline.
- **Changes and their records are atomic.** An entry and its Accountability record are written in one batch or transaction, so neither can exist without the other.
- **Time is checked by the server.** A hostel's period and the month lock are compared with the server's clock in the rules, so changing a phone's date cannot extend a hostel or reopen a month.

## Data model

```text
users/{uid}                        Profile, nickname, current hostel, and role
groups/{groupId}                   Hostel: name, memberIds, admins, inviteCode,
                                   settings (permissions), options (Balance
                                   Options and newer settings), duties
  ├── members/{memberId}           App users (id = uid) and members without the app
  ├── meals/{memberId_YYYY-MM-DD}  One document per member per day
  ├── mealPlans/{memberId}         A member's meal plan rules
  ├── expenses/{id}                Expenses; an Initial Share part also has
                                   kind 'initialShare' and a shareId
  ├── monthlySettings/{YYYY-MM}    Minimum meals, shop due, meals turned off
                                   (cancelledMeals), how members who left
                                   count (leavers), rent and shared bills,
                                   and the summary kept for older months
  ├── departures/{id}              Members who left and how they count
  ├── activity/{id}                Accountability records (append-only)
  └── notifications/{id}           Admin announcements and away notices
invites/{code}                     Hostel code → hostel
subscriptions/{groupId}            Active period and super admin switches
vouchers/{code}                    Voucher: days it adds, on/off
  └── redemptions/{groupId}        One record per hostel that used it
payments/{transactionId}           A reported bKash payment and its status
featureRequests/{id}               Ideas sent to the developer from the app
announcements/{id}                 App-wide notices
config/payment                     bKash number and instructions
config/app                         Maintenance mode
config/appUpdate                   Latest version, minimum version, What's New
```

## Security model

All of the following is enforced in [`firestore.rules`](firestore.rules):

| Rule | Why |
|---|---|
| Everything beyond creating your own profile needs a verified email | Stops throwaway and mistyped accounts |
| Hostel data is readable only by its members | Hostels cannot see each other |
| Joining requires the hostel's active code | Codes cannot be listed or guessed from the outside |
| A user's own hostel and role must match the hostel's member and admin lists | Nobody can place themselves in a hostel or make themselves an admin |
| Members write only their own meals, plans and expenses; admins can write for anyone in the hostel | Records cannot be forged for someone else |
| Members' writes are refused when the admins have switched them off | Hostel settings cannot be bypassed |
| Meals and expenses can change only until the 7th of the next month | Closed months cannot be rewritten, even by an admin |
| Accountability records can be added, by their own author at the server's time, but never changed or deleted | The history cannot be hidden or backdated |
| Writes are refused unless the hostel's period is running | Read-only really is read-only |
| A voucher gives exactly its days, once per hostel | Vouchers cannot be reused or inflated |
| A hostel's 7 free days can only be written in the batch that creates it | The free period cannot be repeated or lengthened |
| Feature requests can be sent by anyone signed in, in their own name, and read only by the super admin | Messages stay private |
| Only the super admin changes periods, vouchers, payments, and app settings | Activation cannot be self-granted |

The super admin is identified by a verified email address that appears in two places which must match: `SuperAdminService.email` in the app and `isSuperAdmin()` in the rules.

## Project structure

```text
lib/
├── main.dart                         Entry point; routes by sign-in state and role
├── firebase_options.dart             Generated Firebase configuration
├── models/group_member.dart          A hostel member, with or without an account
├── services/
│   ├── monthly_calculator.dart       Meal rate, balances, closing window (pure)
│   ├── month_archive.dart            Month lock and summaries of older months
│   ├── meal_plan.dart                Meal plan rules and planned meals (pure)
│   ├── duty_roster.dart              Duty dates and clashes
│   ├── dashboard_summary.dart        The Home figures (pure)
│   ├── daily_trend.dart              Month Trend figures (pure)
│   ├── fixed_costs.dart              Rent and shared bills (pure)
│   ├── initial_share.dart            Initial Share split and saving
│   ├── best_manager.dart             Best Manager ranking (pure)
│   ├── expense_items.dart            Itemwise expenses in a description (pure)
│   ├── meal_cancellation*.dart       Meal Off for a day
│   ├── month_rules*.dart             Meal Off and leaving rules for a month
│   ├── member_departure_service.dart Members who leave and how they count
│   ├── edit_mark.dart                When an entry counts as edited (pure)
│   ├── activity_log.dart             Accountability records
│   ├── month_records.dart            One-month meal and expense queries
│   ├── hostel_settings.dart          Hostel settings and Balance Options
│   ├── group_member_service.dart     Members, roles, leaving, linking
│   ├── meal_plan_service.dart        Meal plans in Firestore
│   ├── profile_service.dart          Nickname
│   ├── account_rules.dart            Name, phone and password rules
│   ├── sign_in_limiter.dart          Wrong-password lockout
│   ├── feature_request_service.dart  Feature requests
│   ├── subscription_service.dart     Activation, vouchers, payments, app config
│   ├── notification_service.dart     Hostel notifications and app notices
│   ├── super_admin_service.dart      Super admin identity and data
│   ├── update_service.dart           Update settings, in-app update, What's New
│   ├── abi/                          Whether the phone needs the 32-bit APK
│   └── error_messages.dart           User-facing messages for refused saves
├── screens/                          One file per screen: phone shell, Home,
│                                     Meals, Expenses, Balance, Balance Options,
│                                     Initial Share, share picture,
│                                     Accountability, Admin Settings, Guide,
│                                     super admin…
├── widgets/                          Month calendar, Month Trend chart, tiles,
│                                     sign-in branding (onboarding.dart),
│                                     super admin desktop layout, update prompt…
└── theme/app_theme.dart              Colours, font and component styles
assets/fonts/                         Manrope
test/                                 Unit and widget tests
website/                              The landing page at hostelmate.web.app and its
                                      link preview image (og-image.png)
tool/build_site.py                    Builds the website and web app for hosting
firestore.rules                       Security rules
```

## Getting started

### Requirements

- Flutter SDK (Dart 3.13 or newer)
- Android Studio or the Android SDK
- Firebase CLI and FlutterFire CLI
- A Firebase project with **Authentication** (email/password) and **Cloud Firestore** enabled

### Setup

```bash
git clone https://github.com/adnanshad35/hostel-meal-calculator.git
cd hostel-meal-calculator
flutter pub get
```

Point the app at your own Firebase project and deploy the rules:

```bash
flutterfire configure
firebase deploy --only firestore:rules
```

Set the super admin's email in both places, then register that account in the app and verify it:

- `lib/services/super_admin_service.dart` → `SuperAdminService.email`
- `firestore.rules` → `isSuperAdmin()`

Run the app:

```bash
flutter run              # Android
flutter run -d chrome    # web
```

### First run

1. Sign in as the super admin and create a voucher under **Vouchers**.
2. Sign in as a normal user and create a hostel. It is active for 7 free days, and the voucher extends it.
3. Share the hostel's code with its members.

## Testing

```bash
flutter analyze lib
flutter test
```

The suite has 253 tests. The areas that decide money and access are covered most heavily:

| Area | What is tested |
|---|---|
| Monthly calculation | Meal rate, balances, minimum meals, shop due, month boundaries, former members, rounding, closing window |
| Month lock and edits | Which months can change, older-month summaries, the one-minute edited rule |
| Accountability | Record wording, tones, change details, unseen dot |
| Meal plans | Ranges, open-ended plans, lunch or dinner starts and ends, days with entries |
| Home and settings | Summary figures, Month Trend, hostel settings defaults |
| Duty roster | Turns, clashes, who is on duty |
| Balance Options | Switch history by month, saving under `options`, older settings read back, Fixed Costs counting only since it was switched on |
| Initial Share and Best Manager | Equal split, calculation, turns of 3+ days, ranking against the average |
| Expenses | Itemwise lines saved and read back, changed expenses opening as Simple |
| Fixed costs | Equal split, per-member rent, carry-forward and reset |
| Activation | Active and ended periods, time left, extending, voucher and transaction ID formats |
| Profile | Nickname rules, the name shown in the hostel |
| Super admin, notifications, updates | Counts and search, unread counts, update settings, required and optional updates, the 32-bit APK for 32-bit phones |
| Widgets | Month calendar, Guide, meal counter, billing screens, desktop layout, update and maintenance screens |

The security rules are not covered by automated tests. The month lock was checked against the Firebase Rules test API; the rest is verified manually against the live project.

## Releasing and deploying

**Android release**

1. Raise `version` in `pubspec.yaml` (for example `1.9.0+13` → `1.9.1+14`).
2. Build both APKs, one at a time (each build overwrites `app-release.apk`), and keep them in `build/release/`:
   ```bash
   flutter build apk --release --target-platform android-arm64   # → build/release/HostelMate.apk
   flutter build apk --release --target-platform android-arm     # → build/release/HostelMate-32bit.apk
   ```
   One ABI each keeps the downloads small (about 22 MB and 20 MB).
3. Publish a GitHub release tagged `v<version>`, with both files attached as `HostelMate.apk` and `HostelMate-32bit.apk`.
4. Deploy the security rules if they changed, then the website and web app (below).
5. In the super admin panel, open **App Update** and set the **Latest Version** and **What's New**. Leave **APK Link** empty so each phone downloads its own file, and set a **Minimum Version** only if the update must be installed.

Pushing commits alone never affects users.

**Website and web app**

```bash
python tool/build_site.py
firebase deploy --only hosting
```

**Security rules**

```bash
firebase deploy --only firestore:rules
```

## Known limitations

- **No iPhone app.** iPhone users use the web version.
- **In-app notifications only.** Nothing is delivered while the app is closed.
- **Internet required for changes.** Cached data can be viewed offline, but saves need a connection.
- **Distributed outside the Play Store.** Users install from a link; Chrome holds the download until they choose **Download anyway**, and Android asks them to allow the install. The website explains both.
- **Sign-in emails come from Firebase's address** (`noreply@…firebaseapp.com`), as email templates cannot be changed on this project yet. The Verify Email page says so.
- **No automatic backups.** The project is on Firebase's free plan; a manual backup download is planned ([#8](https://github.com/adnanshad35/hostel-meal-calculator/issues/8)).
- **English only.**

## Roadmap

- A Play Store listing
- Bangla language
- Meal reminders for missing entries
- Entering meals and expenses offline
- A **Download Backup** button for the super admin
- Push notifications
- Automated tests for the security rules

## Developer

**Abu Adnan Shad**: BSc in CSE, Leading University. Design, development, and maintenance.

- LinkedIn: [Abu Adnan Shad](https://www.linkedin.com/in/abuadnanshad/)
- GitHub: [adnanshad35](https://github.com/adnanshad35)

Feature requests are welcome through **Request a Feature** in the app, and bug reports by opening an issue.
