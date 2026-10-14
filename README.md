# HostelMate

**A shared meal and expense manager for hostels and messes.**

HostelMate replaces the handwritten meal register and the end-of-month calculator. Members record their meals and what they spend; the app works out the meal rate and shows each person the one amount they pay or collect. Everyone in the hostel sees the same figures, so there is nothing to argue about.

It is built with Flutter and Firebase and runs on Android and in the browser. There is no server code: every permission is enforced by Firestore Security Rules.

**[Download for Android](https://github.com/adnanshad35/hostel-meal-calculator/releases/latest/download/HostelMate.apk)** · **[Open the web version](https://hostelmate.web.app/app/)** · **[Website](https://hostelmate.web.app)**

---

## Contents

- [The problem it solves](#the-problem-it-solves)
- [Who uses it](#who-uses-it)
- [Features](#features)
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
- every member can open the app and see how their amount was reached.

## Who uses it

| Role | Who they are | What they can do |
|---|---|---|
| **Member** | Anyone living in the hostel | Record their own meals and expenses (if the admins allow it), set their meal plan, view the hostel's records and calculation |
| **Hostel admin** | One or more members who run the hostel | Everything a member can do, plus manage members and duty dates, record entries for others, set the month's minimum meals and shop due, change hostel settings, post announcements, activate the hostel |
| **Super admin** | The app's owner (one account) | Oversee every hostel and user, manage vouchers and payments, read feature requests, pause the app, send app-wide notices |

Hostels often include people who will never install an app. An admin can add them **by name only**; their meals and expenses are recorded by the admin and they are included in every calculation. If they later join with an account, the admin can link the two and their history moves across.

## Features

### Dashboard

- The month's meal rate, with the member's own expense and meal count, each opening their own records
- **For today**: how many lunches and dinners the hostel is having, who is eating each, and which member is on duty
- One-tap **Add meal** and **Add expense**, shown only when the member is allowed to add them
- Links to the whole hostel's meals and expenses, and to About Hostel

### Meals

- Record lunch and dinner for any day of the current month, in steps of one (halves can be typed)
- **Meal plans**: a member's usual lunch and dinner for a range of days, or until changed; days without an entry are counted from the plan
- Admins can record or correct meals for any member, including members without the app
- A month calendar shows every day's meals, for the hostel or for one member

### Expenses

- Record an expense with a name, an optional description, an amount, and who paid
- A built-in calculator for the amount, without opening the phone keyboard
- Admins can add expenses for any member and delete entries
- A month calendar shows every day's expenses, for the hostel or for one member

### Details (the monthly calculation)

- The meal rate, total meals, total cost, minimum meals and shop due on one card, with the change from last month
- Every member's balance, **Pay** or **Collect**; tapping a member shows their meals, meal cost and spending
- **Copy** produces a WhatsApp-ready summary or the full table
- Any earlier month can be opened to review its figures
- The minimum meals and shop due can be entered from the 25th of the month to the 5th of the next, unless an admin switches on **Special permission**

### Hostel management

- Create a hostel and receive a six-character invitation code; switch joining off and on
- Multiple admins per hostel; the last admin cannot leave or be demoted
- **Settings**: whether members can add meals, whether members can add expenses, special permission, members without the app, and a reset of the current month
- **Duty roster**: which member looks after the hostel on which dates, with clash checks
- A member list sorted by duty, with the subscription's remaining time

### Profile

- **Nickname**: one word of up to 12 letters, shown inside the hostel instead of the full name
- Password change by email
- **App and Developer**: about the app, the website, the developer's contacts, and **Request a Feature**, which sends a message straight to the super admin

### Notifications

- **Inside a hostel:** announcements written by admins (up to 50 words) and an alert whenever a member adds an expense
- **App-wide:** notices from the super admin, shown as a pop-up and kept in a list
- An unread count appears on each bell icon

Notifications are in-app. They appear while the app is open and the next time it is opened; they are not pushed to a closed phone.

### Super admin panel

The super admin's account opens directly into an administration panel, with a desktop layout on wide screens:

- **Overview**: users, hostels, active hostels, payments waiting, and sign-ups this week
- **Users**: every account, searchable and sortable
- **Hostels**: every hostel with its status; set its remaining days, switch editing or access off, or delete it
- **Payments**: publish the bKash number and instructions, approve or reject reported payments
- **Vouchers**: create voucher codes and switch them off
- **Requests**: feature requests sent from the app
- **Maintenance mode** and **app notices**

### Web version and updates

- The same app runs at [hostelmate.web.app/app](https://hostelmate.web.app/app/), with the same accounts and data
- On launch the Android app compares its version with the latest GitHub release; if a newer one exists, the user must update before continuing, so every member of a hostel is on the same version

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
- **Minimum meals and shop due** are set per month and start at zero each month.
- **Rent and shared bills.** The calculation engine supports per-member rent and equally shared bills (`FixedCostsCalculator`). The screens for them are hidden while a redesigned version is prepared.

## Hostel activation

A hostel is **active** for a number of days. When the period ends it becomes **read-only**: every record stays visible, but meals, expenses, and monthly settings cannot be added or changed until it is activated again.

A hostel admin activates or extends the hostel in one of two ways:

1. **Voucher.** Enter a code issued by the super admin. Each hostel can use a given voucher once. Extending an active hostel adds days to the end of its period.
2. **bKash payment.** Send the payment, then submit the transaction ID, amount, and sender number. The super admin checks it and approves it with the number of days to add. A transaction ID can be submitted only once.

Payments are verified manually on purpose: it needs no payment-gateway account and no server.

## Architecture

```text
┌──────────────────────────────────────────────┐
│  Screens (lib/screens)                       │  One file per screen
├──────────────────────────────────────────────┤
│  Widgets (lib/widgets)                       │  Shared UI: calendar, counter…
├──────────────────────────────────────────────┤
│  Services (lib/services)                     │  Data access + business logic
│   ├─ pure logic: calculator, meal plans,     │  No Firebase; unit tested
│   │   duty roster, dashboard summary         │
│   └─ Firestore access: members, settings…    │
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
- **Time is checked by the server.** A hostel's period is stored as a start time plus a number of days, and the rules compare that with the server's clock, so changing a phone's date cannot extend a hostel.

## Data model

```text
users/{uid}                        Profile, nickname, current hostel, and role
groups/{groupId}                   Hostel: name, memberIds, admins, inviteCode,
                                   settings, duties
  ├── members/{memberId}           App users (id = uid) and members without the app
  ├── meals/{memberId_YYYY-MM-DD}  One document per member per day
  ├── mealPlans/{memberId}         A member's meal plan rules
  ├── expenses/{id}                Expenses
  ├── monthlySettings/{YYYY-MM}    Minimum meals, shop due, rents, shared bills
  └── notifications/{id}           Admin announcements and expense alerts
invites/{code}                     Invitation code → hostel
subscriptions/{groupId}            Active period and super admin switches
vouchers/{code}                    Voucher: days it adds, on/off
  └── redemptions/{groupId}        One record per hostel that used it
payments/{transactionId}           A reported bKash payment and its status
featureRequests/{id}               Ideas sent to the developer from the app
announcements/{id}                 App-wide notices
config/payment                     bKash number and instructions
config/app                         Maintenance mode
```

## Security model

All of the following is enforced in [`firestore.rules`](firestore.rules):

| Rule | Why |
|---|---|
| Everything beyond creating your own profile needs a verified email | Stops throwaway and mistyped accounts |
| Hostel data is readable only by its members | Hostels cannot see each other |
| Joining requires the hostel's active invitation code | Codes cannot be listed or guessed from the outside |
| A user's own hostel and role must match the hostel's member and admin lists | Nobody can place themselves in a hostel or make themselves an admin |
| Members write only their own meals, plans and expenses; admins can write for anyone in the hostel | Records cannot be forged for someone else |
| Members' writes are refused when the admins have switched them off | Hostel settings cannot be bypassed |
| Writes are refused unless the hostel's period is running | Read-only really is read-only |
| A voucher gives exactly its days, once per hostel | Vouchers cannot be reused or inflated |
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
│   ├── meal_plan.dart                Meal plan rules and planned meals (pure)
│   ├── duty_roster.dart              Duty dates and clashes
│   ├── dashboard_summary.dart        The dashboard's figures (pure)
│   ├── fixed_costs.dart              Rent and shared bills (pure)
│   ├── month_records.dart            One-month meal and expense queries
│   ├── hostel_settings.dart          Hostel settings
│   ├── group_member_service.dart     Members, roles, leaving, linking
│   ├── meal_plan_service.dart        Meal plans in Firestore
│   ├── profile_service.dart          Nickname
│   ├── feature_request_service.dart  Feature requests
│   ├── subscription_service.dart     Activation, vouchers, payments, app config
│   ├── notification_service.dart     Hostel notifications and app notices
│   ├── super_admin_service.dart      Super admin identity and data
│   ├── update_service.dart           Version check against GitHub releases
│   └── error_messages.dart           User-facing messages for refused saves
├── screens/                          One file per screen: sign-in, dashboard,
│                                     meals, expenses, Details, settings, duty
│                                     roster, profile, super admin…
├── widgets/                          Month calendar, meal counter, desktop
│                                     layout, update prompt, maintenance gate…
└── theme/app_theme.dart              Colours, font and component styles
assets/fonts/                         Manrope
test/                                 Unit and widget tests
website/                              The landing page at hostelmate.web.app
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
2. Sign in as a normal user, create a hostel, and activate it with the voucher.
3. Share the hostel's invitation code with its members.

## Testing

```bash
flutter analyze
flutter test
```

The suite has 158 tests. The areas that decide money and access are covered most heavily:

| Area | What is tested |
|---|---|
| Monthly calculation | Meal rate, balances, minimum meals, shop due, month boundaries, former members, rounding, closing window |
| Meal plans | Ranges, open-ended plans, lunch or dinner starts and ends, days with entries |
| Dashboard and settings | Summary figures, hostel settings defaults |
| Duty roster | Turns, clashes, who is on duty |
| Fixed costs | Equal split, per-member rent, carry-forward and reset |
| Activation | Active and ended periods, time left, extending, voucher and transaction ID formats |
| Profile | Nickname rules, the name shown in the hostel |
| Super admin, notifications, updates | Counts and search, unread counts, version comparison |
| Widgets | Meal counter, billing screens, desktop layout, update and maintenance screens |

The security rules are not covered by automated tests; they are verified manually against the live project.

## Releasing and deploying

**Android release**

1. Raise `version` in `pubspec.yaml` (for example `1.5.0+8` → `1.5.1+9`).
2. Build the APK:
   ```bash
   flutter build apk --release --target-platform android-arm,android-arm64
   ```
3. Publish a GitHub release tagged `v<version>`, with the APK attached under the name `HostelMate.apk`.

From that moment, installed apps on an older version require an update on their next launch. Pushing commits alone never affects users.

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
- **Manual payment verification.** Each bKash payment is checked by hand.
- **Internet required for changes.** Cached data can be viewed offline, but saves need a connection.
- **Distributed outside the Play Store.** Users install from a link and Android asks them to allow it.
- **English only.**

## Roadmap

- A permanent release signing key and a Play Store listing
- Calculate other costs (rent and shared bills), redesigned
- Bangla language
- Push notifications
- Automated tests for the security rules

## Developer

**Abu Adnan Shad**: design, development, and maintenance

- LinkedIn: [Abu Adnan Shad](https://www.linkedin.com/in/abuadnanshad/)
- GitHub: [adnanshad35](https://github.com/adnanshad35)

Feature requests are welcome through **Request a Feature** in the app, and bug reports by opening an issue.
