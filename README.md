# HostelMate

HostelMate is an Android application for managing shared hostel meals and expenses. It replaces handwritten meal records and manual monthly calculations with a transparent system that every hostel member can access.

The application is built with Flutter and Firebase. It has three levels of access: hostel members, hostel administrators, and a single app-wide super admin.

**Download:** [latest Android release](https://github.com/adnanshad35/hostel-meal-calculator/releases/latest/download/HostelMate.apk)

## Features

### Hostel groups

- Create a hostel and receive a unique invitation code
- Join a hostel with its invitation code; admins can switch joining off
- Add members who do not use the app, and link them to an account later
- Leave a hostel without removing previous financial records

### Meals

- Record lunch and dinner for any day of the month, in half-meal steps or by typing
- Administrators can record meals for any member
- Monthly ledger of every member's entries

### Expenses

- Add shared expenses and record who paid
- Administrators can add expenses on behalf of members, and delete entries
- Screens show the current month, matching the monthly calculation

### Monthly calculation

The calculation is split into three tabs, each with a copyable summary:

- **Meals** — meal rate and each member's meal balance
- **Fixed** — per-member rent and equally shared bills (Wi-Fi, electricity, chef), carried forward each month until changed
- **Overall** — one final amount per member: meals plus fixed costs

```text
Meal rate           = (Member-paid expenses + Shop due) ÷ Charged meals
Member meal expense = Meal rate × Member charged meals
Meal balance        = Amount spent − Member meal expense
Overall             = Meal balance − Rent − Share of bills
```

A positive amount means the member collects money; a negative amount means the member pays. Administrators can set a minimum monthly meal count, in which case a member is charged for at least that many meals.

### Notifications

- Hostel announcements from administrators (up to 50 words) and new-expense alerts, shown inside the hostel
- App notices from the super admin, shown on the home screen

Notifications are in-app: they appear while the app is open and the next time it is opened.

### Hostel activation

A hostel is active for a period of days and read-only afterwards: records remain visible but cannot be changed. A hostel administrator activates or extends it by:

- entering a voucher code, or
- reporting a bKash payment (transaction ID), which the super admin reviews and approves

### Super admin

One account, identified by a verified email, opens directly into an administration panel:

- Overview of users, hostels, active hostels, and payments waiting
- Every user and hostel, searchable
- Per hostel: add or set its remaining days, switch editing or access off
- Vouchers: create codes and switch them off
- Payments: publish payment details, approve or reject reported payments
- Maintenance mode for the whole app, and app notices

### Updates

On launch the app checks the latest GitHub release and requires users on an older version to update.

## Technology

- **Flutter** and **Dart**
- **Firebase Authentication** for accounts and email verification
- **Cloud Firestore** for real-time data
- **Firestore Security Rules** for all access control; there is no server code

## Project structure

```text
lib/
├── main.dart                 App entry point and sign-in routing
├── firebase_options.dart
├── models/                   Plain data classes
├── services/                 Data access and calculation logic
│   ├── monthly_calculator.dart     Meal rate and balances
│   ├── fixed_costs.dart            Rent and shared bills
│   ├── group_member_service.dart   Members, roles, joining, leaving
│   ├── subscription_service.dart   Activation, vouchers, payments
│   ├── notification_service.dart
│   ├── super_admin_service.dart
│   └── update_service.dart
├── screens/                  One file per screen
├── widgets/                  Shared widgets
└── theme/
test/                         Unit and widget tests
firestore.rules               Security rules
```

The calculation logic in `services/` has no Firebase dependency and is covered by unit tests.

## Data model

```text
users/{uid}                          Profile, hostel, and role
groups/{groupId}                     Hostel: name, members, admins, invite code
  ├── members/{memberId}             App users and members without the app
  ├── meals/{memberId_date}          Daily lunch and dinner
  ├── expenses/{id}                  Shared expenses
  ├── monthlySettings/{YYYY-MM}      Minimum meals, shop due, fixed costs
  └── notifications/{id}             Announcements and expense alerts
invites/{code}                       Invitation code → hostel
subscriptions/{groupId}              Active period and super admin switches
vouchers/{code}                      Voucher codes and their redemptions
payments/{transactionId}             Reported bKash payments
announcements/{id}                   App notices
config/{document}                    Payment details and maintenance mode
```

## Getting started

### Requirements

- Flutter SDK
- Android Studio or the Android SDK
- Firebase CLI and FlutterFire CLI

### Installation

```bash
git clone https://github.com/adnanshad35/hostel-meal-calculator.git
cd hostel-meal-calculator
flutter pub get
```

Configure your own Firebase project and deploy the security rules:

```bash
flutterfire configure
firebase deploy --only firestore:rules
```

The super admin's email is set in two places that must match: `SuperAdminService.email` in `lib/services/super_admin_service.dart` and `isSuperAdmin()` in `firestore.rules`.

Check and run the project:

```bash
flutter analyze
flutter test
flutter run
```

### Releasing

1. Raise `version` in `pubspec.yaml`.
2. Build the APK: `flutter build apk --release --target-platform android-arm,android-arm64`
3. Publish a GitHub release tagged `v<version>` with the APK attached as `HostelMate.apk`.

Installed apps on an older version are then asked to update.

## Developer

**Abu Adnan Shad**

- GitHub: [adnanshad35](https://github.com/adnanshad35)
- LinkedIn: [Abu Adnan Shad](https://www.linkedin.com/in/abuadnanshad/)
