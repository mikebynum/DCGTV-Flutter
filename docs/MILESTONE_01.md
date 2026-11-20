# Milestone 01 · Flutter foundation and Watch tab

The Watch layout and exact `DCGTVWatchHeader.png` artwork come from the SwiftUI Watch screen in `mikebynum/DCGTV-iOS`. The banner includes the Charter Bank branding and links to its website. Flutter also shows upcoming DCGTV broadcasts from the WordPress feed. The SwiftUI away-stream section uses a separate games feed and is outside this milestone.

## Broadcast refresh

- App startup loads the saved broadcast list before requesting an update. Pull to refresh or use Retry when live status is unverified. Automatic network attempts are at least 60 seconds apart in the foreground.
- The live badge requires the WordPress feed to report a non-stale snapshot with an `updated_at` timestamp less than 120 seconds old. A failed request, expired timestamp, or disk-cache load leaves live status unverified. Available playback links remain usable.
- The request URL varies by minute because WordPress can cache the bare endpoint for five minutes. WordPress still controls when it updates the underlying feed.
- Broadcast times use the device timezone and time format. Recent broadcasts use the feed’s replay list, newest first.

## Validate on a Mac

Use the existing Flutter checkout if it already has generated native files. For a fresh checkout only, generate missing native scaffolding with `flutter create --platforms=ios,android --project-name dcgtv .` and review the generated files before committing them. The native directories generated during earlier local setup are still local.

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

Before merging, validate the layout and browser playback on both Android and iOS, including a real live event. Verify that pull-to-refresh restores current status after reconnecting and that the sponsor banner and YouTube channel links open. Home, Schedule, and Shows remain placeholders in the Flutter app.
