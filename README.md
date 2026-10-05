# HostelMate

HostelMate is an Android application for managing shared hostel meals and expenses. It replaces handwritten meal records and manual monthly calculations with a transparent system that every hostel member can access.

The application is built with Flutter and Firebase and supports separate permissions for hostel administrators and regular members.

## Features

### Hostel groups

- Create a hostel and receive a unique invitation code
- Join an existing hostel using its invitation code
- View hostel information and member count
- Leave a hostel without removing previous financial records

### Meal management

- Record daily meal quantities
- View monthly meal history
- Update personal meal entries
- Allow administrators to manage meals for other members
- Calculate total meals for the selected month

### Expense management

- Add shared hostel expenses
- Record who paid each expense
- Allow administrators to add expenses on behalf of members
- Edit expense information
- Include unpaid shop dues in the monthly calculation

### Monthly calculation

HostelMate automatically calculates:

- Total meal count
- Member-paid expenses
- Outstanding shop dues
- Total monthly cost
- Meal rate
- Individual meal expenses
- Amount spent by each member
- Final amount each member must pay or collect

The basic calculation is:

```text
Meal rate = Total monthly cost ÷ Total effective meals

Member meal expense = Meal rate × Member effective meals

Member balance = Amount spent − Member meal expense
```

A positive balance means the member will collect money, while a negative balance means the member must pay.

Administrators can also set a minimum monthly meal requirement. When enabled, a member is charged for at least the minimum number of meals, even if their actual meal count is lower.

### Member administration

- Separate administrator and member roles
- Promote another member to administrator
- Prevent the final administrator from leaving the hostel
- Allow administrators to manage member meals and expenses
- Preserve previous records when a member leaves

### Account management

- Email and password authentication
- Password reset by email
- User profile with account and hostel information
- Sign-out confirmation
- Feature-request option for contacting the developer

## Technology

- **Flutter** and **Dart** for application development
- **Firebase Authentication** for account management
- **Cloud Firestore** for real-time data storage
- **Firestore Security Rules** for role-based access control
- **URL Launcher** for feature-request emails

## Project structure

```text
lib/
├── main.dart
├── firebase_options.dart
├── theme/
│   └── app_theme.dart
└── screens/
    ├── home_screen.dart
    ├── profile_screen.dart
    ├── login_screen.dart
    ├── register_screen.dart
    ├── forgot_password_screen.dart
    ├── create_group_screen.dart
    ├── join_group_screen.dart
    ├── hostel_dashboard_screen.dart
    ├── meal_screen.dart
    ├── meal_ledger_screen.dart
    ├── admin_meal_edit_screen.dart
    ├── expense_screen.dart
    ├── monthly_summary_screen.dart
    ├── manage_members_screen.dart
    └── group_settings_screen.dart
```

## Getting started

### Requirements

Before running the project, install:

- Flutter SDK
- Android Studio or Android SDK
- Visual Studio Code with the Flutter extension
- Firebase CLI
- FlutterFire CLI

### Installation

Clone the repository:

```bash
git clone https://github.com/adnanshad35/hostel-meal-calculator.git
cd hostel-meal-calculator
```

Install the Flutter packages:

```bash
flutter pub get
```

Configure your own Firebase project:

```bash
flutterfire configure
```

Deploy the Firestore security rules:

```bash
firebase deploy --only firestore:rules
```

Check the project:

```bash
flutter analyze
flutter test
```

Run the application:

```bash
flutter run
```

## Current status

The core hostel-management system is functional. Authentication, hostel groups, meal entry, shared expenses, administrative controls, shop dues, and monthly calculations have been implemented and tested on an Android device.

Further development will focus on interface refinement, stronger account verification, improved reporting, and additional hostel-management features.

## Developer

**Abu Adnan Shad**

- GitHub: [adnanshad35](https://github.com/adnanshad35)
- LinkedIn: [Abu Adnan Shad](https://www.linkedin.com/in/abuadnanshad/)
