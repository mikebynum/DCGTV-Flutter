# Milestone 01: Flutter foundation and Watch tab

Source reference: mikebynum/DCGTV-iOS (SwiftUI). The original repository is not modified.

## Scope
- Dart models matching the existing WordPress streams endpoint
- Shared HTTP client with HTTP status and JSON validation
- Persistent stream cache, stale/live distinction, 60-second throttling and 120-second status expiry
- Watch tab showing live, upcoming and replay broadcasts
- HTTPS-only video links via platform in-app browser
- System light/dark theme and DCG red branding
- Four-tab navigation shell; Home, Schedule and Shows intentionally remain placeholders
- Sponsor acknowledgement with Charter Bank link

## Known gaps / required before merging
1. Native Flutter project scaffolding (android/, ios/, platform manifests) must be generated locally with a Flutter SDK; the GitHub connector can commit text files but the current execution environment has no Flutter/Dart SDK.
2. Run flutter pub get, flutter analyze, flutter test and flutter run on iOS and Android.
3. Compare Watch tab against the live SwiftUI app; replace placeholder header and sponsor text with approved exact DCGTV and Charter Bank assets.
4. Verify device/browser behavior and API payloads, including timezone formats and video links.
5. Add integration/widget tests for offline fallback, lifecycle refresh and video launch.
6. Do not replace the App Store iOS app until feature parity and release validation.

## Local setup (Mac)
Install Flutter SDK and Android Studio. Clone this repository.
Run:
```sh
flutter create --platforms=ios,android --project-name dcgtv .
flutter pub get
flutter analyze
flutter test
flutter run
```
Review generated native files before committing them to the PR. Do not overwrite lib/ or pubspec.yaml with starter templates.
