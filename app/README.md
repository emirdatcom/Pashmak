# App (Flutter, Android)

Flavors: `bazaar`, `myket` (`lib/main_bazaar.dart`, `lib/main_myket.dart`). App identity lives in
`android/brand.properties` (applicationId, launcher name, deep-link scheme).

## Setup
```
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # drift (generated files are committed)
dart run tool/sync_assets.dart                              # copies ../config-data into assets/
dart run tool/gen_analytics_events.dart                     # AnalyticsEvent from config-data/analytics/events.json
flutter run --flavor bazaar -t lib/main_bazaar.dart --dart-define=API_BASE_URL=http://10.0.2.2:8080
```
## Tests
`flutter analyze && flutter test`. The DB tests exercise **real SQLCipher** on the host through the system
library: `sudo apt-get install libsqlcipher1` (Linux). On Android the build hook bundles SQLCipher
(`pubspec.yaml` → `hooks.user_defines.sqlite3`).

## Notes
* All user-facing text comes from `copy.t(key)` (content pack `copy_fa`); `test/no_hardcoded_persian_test.dart` enforces it.
* Encryption key: 32 random bytes in Android Keystore (flutter_secure_storage). If the DB cannot be opened the app shows `DbErrorScreen`.
* **Not verifiable in the authoring environment** (no Android SDK): Gradle flavors, manifest, R8, `flutter build apk`, APK size, the WorkManager task and the `app/device` channel. Run `flutter build apk --flavor bazaar --split-per-abi` in CI/locally and fix anything Gradle reports.
