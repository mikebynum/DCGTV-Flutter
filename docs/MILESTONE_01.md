# Milestone 01 · Flutter foundation and Watch tab

The Watch layout and exact `DCGTVWatchHeader.png` artwork come from the SwiftUI Watch screen in `mikebynum/DCGTV-iOS`. The banner includes the Charter Bank branding and links to its website. Flutter also shows upcoming DCGTV broadcasts from the WordPress feed. The SwiftUI away-stream section uses a separate games feed and is outside this milestone.

## Broadcast refresh

- App startup loads the saved broadcast list before requesting an update. Pull to refresh or use Retry when live status is unverified. Automatic network attempts are at least 60 seconds apart in the foreground.
- The live badge requires the WordPress feed to report a non-stale snapshot with an `updated_at` timestamp less than 120 seconds old. A failed request, expired timestamp, or disk-cache load leaves live status unverified. Available playback links remain usable.
- The request URL varies by minute because WordPress can cache the bare endpoint for five minutes. WordPress still controls when it updates the underlying feed.
- Broadcast times use the device timezone and time format. Recent broadcasts use the feed’s replay list, newest first.

## Build and validate on a Mac

Install Flutter, the Android SDK, and Xcode with an iOS simulator runtime. The Android and iOS project files are included in the repository. From a fresh checkout:

```sh
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build apk --debug
flutter build ios --simulator --debug
```

Select an emulator or simulator in VS Code and run the app to check the live list, sponsor link, and replay playback. Home, Schedule, and Shows are placeholders in this milestone.

The native projects use development app IDs. Configure production IDs, signing, and launcher artwork before distributing the app.
