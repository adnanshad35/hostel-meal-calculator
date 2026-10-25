# HostelMate

Flutter app (Android + web) for shared hostel meals, expenses and monthly balances. Backend is Firebase only: Auth (email/password) and Firestore. There is no server code.

## Folders
- `lib/screens/`: one file per page. The dashboard is `hostel_dashboard_screen.dart`, About Hostel and Members are `hostel_details_screen.dart`, Admin Settings is `group_settings_screen.dart`.
- `lib/services/`: Firestore access and pure-Dart logic (`monthly_calculator`, `meal_plan`, `duty_roster`), which is covered by `test/`.
- `lib/widgets/`: shared widgets, such as `month_calendar.dart`. Theme colours and fonts are in `lib/theme/app_theme.dart`.
- `firestore.rules`: the security rules, which enforce every permission (admin, read-only hostel, member settings).
- `website/`: the landing page. `tool/build_site.py` builds the site and the web app into `build/hosting`.

## Commands
- Check: `flutter analyze lib` and `flutter test`
- APK: `flutter build apk --release` (signed via `android/key.properties`)
- Web: `python tool/build_site.py`, then `firebase deploy --only hosting`
- Rules: `firebase deploy --only firestore:rules`

## Release
Bump `version` in `pubspec.yaml`, then publish a GitHub release tagged `vX.Y.Z` with the APK attached as `HostelMate.apk`. The in-app update check reads the latest release.

## Conventions
- Work on `Ready2Release`; the user merges into `main`.
- UI: Title Case for titles and labels, no helper text on cards, colours from `AppTheme` only (green, ink, brass).
