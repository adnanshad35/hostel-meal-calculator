# HostelMate

**A shared meal and expense manager for hostels and messes.**

HostelMate replaces the handwritten meal register and the end-of-month calculator. Members record their meals and what they spent; the app works out the meal rate, adds rent and shared bills, and shows each person the one amount they pay or collect. Everyone in the hostel sees the same figures, so there is nothing to argue about.

It is an Android application built with Flutter and Firebase, with no server code: every permission is enforced by Firestore Security Rules.

**[Download the latest Android release](https://github.com/adnanshad35/hostel-meal-calculator/releases/latest/download/HostelMate.apk)** · Android 7.0 or newer · about 36 MB

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
- [Releasing a new version](#releasing-a-new-version)
- [Known limitations](#known-limitations)
- [Roadmap](#roadmap)
- [Developer](#developer)

---

## The problem it solves

In a shared hostel, one person usually keeps a notebook of who ate how many meals and who paid for groceries. At the end of the month that person adds everything up by hand, divides the cost by the meals, and tells each member what they owe. The process is slow, mistakes are common, and members have to trust figures they cannot check.

HostelMate keeps the same records in one shared place:

- each member enters their own meals and expenses, so the data is not one person's job;
- the calculation is automatic and identical for everyone;
- every member can open the app and see how their amount was reached.

## Who uses it

| Role | Who they are | What they can do |
|---|---|---|
| **Member** | Anyone living in the hostel | Record their own meals and expenses; view the hostel's records and calculation |
| **Hostel admin** | One or more members who run the hostel | Everything a member can do, plus manage members, record entries for others, set monthly costs, post announcements, activate the hostel |
| **Super admin** | The app's owner (one account) | Oversee every hostel and user, manage vouchers and payments, pause the app, send app-wide notices |

Hostels often include people who will never install an app. An admin can add them **by name only**; their meals and expenses are recorded by the admin and they are included in every calculation. If they later join with an account, the admin can link the two and their history moves across.

## Features

### Accounts

- Sign up with email and password; the email must be verified before the app can be used
- Password reset by email
- Profile with phone number, password change, app information, and sign-out

### Hostels

- Create a hostel and receive a six-character invitation code
- Join a hostel by entering its code; admins can switch joining off and on
- Multiple admins per hostel; the last admin cannot leave or be demoted
- Add members without the app, rename or deactivate them, and link them to an account later
- Leaving or being removed keeps a member's past meals and expenses in the hostel's records

### Meals

- Record lunch and dinner for any day of the current month
- Quantities change in half-meal steps with − and + buttons, or can be typed directly
- Admins can record or correct meals for any member, including members without the app
- A monthly ledger shows every member's entry for every day

### Expenses

- Record a shared expense with a name, amount, date, and who paid
- Enter an amount directly or build it with the built-in calculator
- Admins can add expenses on behalf of any member and delete entries
- Screens show the current month, matching what the calculation counts

### Monthly calculation

One screen, three tabs, each with a list of one amount per member and a **Copy** button that produces a WhatsApp-ready summary:

- **Meals** — the meal rate and each member's meal balance, with a details view of meals, spending, and meal expense
- **Fixed** — each member's rent plus their equal share of shared bills such as Wi-Fi, electricity, and the chef
- **Overall** — the final amount per member: meals and fixed costs together

Admins can also set a **minimum meal count** (members below it are charged for the minimum) and a **shop due** (an unpaid grocery balance added to the month's cost). Any earlier month can be opened to review its figures.

### Notifications

- **Inside a hostel:** announcements written by admins (up to 50 words) and an alert whenever a member adds an expense
- **App-wide:** notices from the super admin, shown as a pop-up and kept in a list on the home screen
- An unread count appears on each bell icon

Notifications are in-app. They appear while the app is open and the next time it is opened; they are not pushed to a closed phone.

### Super admin panel

The super admin's account opens directly into an administration panel instead of a hostel:

- **Overview** — total users, users in hostels, hostels, active hostels, payments waiting, and sign-ups this week
- **Users** — every account, searchable by name, email, phone, or hostel, sortable by sign-up date
- **Hostels** — every hostel with its status; add or set its remaining days, or switch its editing or access off
- **Payments** — publish the bKash number and instructions, then approve or reject reported payments
- **Vouchers** — create voucher codes and switch them off
- **Maintenance mode** — pause the app for everyone else, with a custom message
- **App notices** — send a notice to every user

### Automatic updates

On launch the app compares its version with the latest GitHub release. If a newer one exists, the user must update before continuing, so every member of a hostel is always on the same version.

## How the monthly calculation works

```text
Total cost       = Expenses paid by members + Shop due
Charged meals    = max(Meals eaten, Minimum meals)      for each member
Meal rate        = Total cost ÷ Sum of charged meals

Meal expense     = Meal rate × Charged meals            for each member
Meal balance     = Amount the member paid − Meal expense

Bill share       = Sum of shared bills ÷ Number of current members
Overall          = Meal balance − Rent − Bill share
```

A **positive** result means the member collects money; a **negative** result means the member pays. Results are rounded to a whole taka once, at the end.

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

Now add fixed costs: Adnan's rent is ৳3,000, Rahim's is ৳2,500, and the shared bills are Wi-Fi ৳600 and electricity ৳900 (৳1,500, so ৳750 each):

```text
Adnan: +300 − 3,000 − 750 = −3,450   → pays ৳3,450
Rahim: −800 − 2,500 − 750 = −4,050   → pays ৳4,050
```

### Rules worth knowing

- **Former members.** Someone who left but has meals or expenses in a month still appears in that month's calculation under their saved name. They are not charged a share of the bills.
- **Fixed costs carry forward.** Rent and bills apply from the month they are saved until an admin changes or resets them. Editing a later month never changes an earlier one.
- **Members without entries.** A member with no meals and no minimum simply has a zero meal balance.

## Hostel activation

A hostel is **active** for a number of days. When the period ends it becomes **read-only**: every record stays visible, but meals, expenses, and monthly settings cannot be added or changed until it is activated again.

A hostel admin activates or extends the hostel in one of two ways:

1. **Voucher.** Enter a code issued by the super admin. Each hostel can use a given voucher once. Extending an active hostel adds days to the end of its period.
2. **bKash payment.** Send the payment, then submit the transaction ID, amount, and sender number. The super admin checks it against bKash and approves it with the number of days to add. A transaction ID can be submitted only once.

The super admin can also add or set a hostel's days directly, make an active hostel read-only, or suspend it entirely.

Payments are verified manually on purpose: it needs no payment-gateway account and no server.

## Architecture

```text
┌──────────────────────────────────────────────┐
│  Screens (lib/screens)                       │  One file per screen
├──────────────────────────────────────────────┤
│  Widgets (lib/widgets)                       │  Shared UI pieces
├──────────────────────────────────────────────┤
│  Services (lib/services)                     │  Data access + business logic
│   ├─ pure logic: calculator, fixed costs     │  No Firebase; unit tested
│   └─ Firestore access: members, activation…  │
├──────────────────────────────────────────────┤
│  Firebase Authentication · Cloud Firestore   │
│  Firestore Security Rules (firestore.rules)  │  All authorization
└──────────────────────────────────────────────┘
```

Design decisions:

- **No backend code.** The app talks to Firestore directly. Anything a user must not be able to do is refused by the security rules, not hidden in the interface.
- **Calculation logic is pure Dart.** `MonthlyCalculator` and `FixedCostsCalculator` take plain values and return plain values, so the money logic is tested without a database.
- **Live data.** Screens listen to Firestore, so a meal entered on one phone appears on the others without refreshing, and cached data is shown when offline.
- **Time is checked by the server.** A hostel's period is stored as a start time plus a number of days. The rules compare that with the server's clock, so changing a phone's date cannot extend a hostel.

## Data model

```text
users/{uid}                        Profile, current hostel, and role
groups/{groupId}                   Hostel: name, memberIds, admins, inviteCode
  ├── members/{memberId}           App users (id = uid) and members without the app
  ├── meals/{memberId_YYYY-MM-DD}  One document per member per day
  ├── expenses/{id}                Shared expenses
  ├── monthlySettings/{YYYY-MM}    Minimum meals, shop due, rents, shared bills
  └── notifications/{id}           Admin announcements and expense alerts
invites/{code}                     Invitation code → hostel
subscriptions/{groupId}            Active period and super admin switches
vouchers/{code}                    Voucher: days it adds, on/off
  └── redemptions/{groupId}        One record per hostel that used it
payments/{transactionId}           A reported bKash payment and its status
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
| Members write only their own meals and expenses; admins can write for anyone in the hostel | Records cannot be forged for someone else |
| Writes are refused unless the hostel's period is running | Read-only really is read-only |
| A voucher gives exactly its days, once per hostel | Vouchers cannot be reused or inflated |
| Only the super admin changes periods, vouchers, payments, and app settings | Activation cannot be self-granted |

The super admin is identified by a verified email address that appears in two places which must match: `SuperAdminService.email` in the app and `isSuperAdmin()` in the rules.

## Project structure

```text
lib/
├── main.dart                         Entry point; routes by sign-in state and role
├── firebase_options.dart             Generated Firebase configuration
├── models/
│   └── group_member.dart             A hostel member, with or without an account
├── services/
│   ├── monthly_calculator.dart       Meal rate and balances (pure)
│   ├── fixed_costs.dart              Rent, shared bills, carry-forward (pure)
│   ├── group_member_service.dart     Members, roles, leaving, linking
│   ├── subscription_service.dart     Activation, vouchers, payments, app config
│   ├── notification_service.dart     Hostel notifications and app notices
│   ├── super_admin_service.dart      Super admin identity and data
│   ├── update_service.dart           Version check against GitHub releases
│   └── error_messages.dart           User-facing messages for refused saves
├── screens/
│   ├── login, register, verify_email, forgot_password
│   ├── home_screen.dart              Create, join, or open a hostel
│   ├── hostel_dashboard_screen.dart  A hostel's home, with its status
│   ├── meal_screen.dart              Add Meal dialog and monthly totals
│   ├── meal_ledger_screen.dart       Every member's meals by day
│   ├── expense_screen.dart           Expenses and the amount calculator
│   ├── monthly_summary_screen.dart   Meals / Fixed / Overall
│   ├── fixed_costs_screen.dart       Rent and shared bills editor
│   ├── hostel_details_screen.dart    Members, roles, leave hostel
│   ├── group_settings_screen.dart    Admin tools for one hostel
│   ├── hostel_activation_screen.dart Voucher and bKash payment
│   ├── notifications_screen.dart
│   ├── super_admin_screen.dart       Overview, users, hostels
│   ├── super_admin_billing.dart      Payments, vouchers, maintenance
│   ├── profile_screen.dart
│   └── about_screen.dart
├── widgets/                          Meal counter, notification bell, update
│                                     prompt, maintenance gate, name dialog
└── theme/app_theme.dart              Colours and component styles
test/                                 Unit and widget tests
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
flutter run
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

The suite has 100 tests. The areas that decide money and access are covered most heavily:

| Area | What is tested |
|---|---|
| Monthly calculation | Meal rate, balances, minimum meals, shop due, month boundaries, former members, rounding |
| Fixed costs | Equal split, per-member rent, former members, carry-forward and reset |
| Activation | Active and ended periods, days left, extending, voucher and transaction ID formats |
| Super admin | Counts, search, sorting |
| Notifications | Unread counts, word limit |
| Updates | Version comparison, release detection |
| Widgets | Meal counter, billing screens, update and maintenance screens |

The security rules are not covered by automated tests; they are verified manually against the live project.

## Releasing a new version

1. Raise `version` in `pubspec.yaml` (for example `1.3.0+6` → `1.3.1+7`).
2. Build the APK:
   ```bash
   flutter build apk --release --target-platform android-arm,android-arm64
   ```
3. Publish a GitHub release tagged `v<version>`, with the APK attached under the name `HostelMate.apk`.

From that moment, installed apps on an older version require an update on their next launch. Pushing commits alone never affects users.

## Known limitations

- **Android only.** There is no iOS or web version yet.
- **In-app notifications only.** Nothing is delivered while the app is closed.
- **Manual payment verification.** Each bKash payment is checked by hand.
- **Internet required for changes.** Cached data can be viewed offline, but most saves need a connection.
- **Distributed outside the Play Store.** Users install from a link and Android asks them to allow it.
- **Whole-history loading.** Some screens load a hostel's full meal and expense history; fine at the current scale, but worth narrowing as hostels accumulate data.

## Roadmap

- Web version, so iPhone and laptop users can take part
- Push notifications
- Packages and pricing for activation
- Automated tests for the security rules
- Month-scoped data loading

## Developer

**Abu Adnan Shad** — design, development, and maintenance

- GitHub: [adnanshad35](https://github.com/adnanshad35)
- LinkedIn: [Abu Adnan Shad](https://www.linkedin.com/in/abuadnanshad/)

Feature requests and bug reports are welcome through the **Request a Feature** option in the app or by opening an issue.
