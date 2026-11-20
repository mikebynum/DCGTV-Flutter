import '../../models/dcg_game.dart';
import '../../models/dcg_stream.dart';

const _inactiveGameStatuses = {'canceled', 'cancelled', 'postponed'};
final _testBroadcastTitle =
    RegExp(r'^(?:\[test\]|test\b)', caseSensitive: false);

DcgGame? nextScheduledGame(Iterable<DcgGame> games, DateTime now) {
  DcgGame? next;
  DateTime? nextStart;
  for (final game in games) {
    final start = game.start;
    if (start == null || start.isBefore(now)) continue;
    if (_inactiveGameStatuses.contains(game.status?.toLowerCase())) continue;
    if (nextStart == null || start.isBefore(nextStart)) {
      next = game;
      nextStart = start;
    }
  }
  return next;
}

enum FeaturedKind {
  live('LIVE', 'Watch Live'),
  upcoming('Upcoming', 'View Upcoming Stream'),
  replay('Replay', 'Watch Replay');

  const FeaturedKind(this.label, this.action);

  final String label;
  final String action;
}

class FeaturedBroadcast {
  const FeaturedBroadcast(this.stream, this.kind, this.url);

  final DcgStream stream;
  final FeaturedKind kind;
  final Uri url;
}

/// The streams repository orders scheduled broadcasts soonest first and
/// replays newest first. Cached live entries never qualify as verified live.
FeaturedBroadcast? selectFeaturedBroadcast({
  required Iterable<DcgStream> streams,
  required Iterable<DcgStream> replays,
  required bool isStatusCurrent,
  required DateTime now,
}) {
  FeaturedBroadcast? upcoming;
  for (final stream in streams) {
    final url = stream.safeUrl;
    if (url == null || _testBroadcastTitle.hasMatch(stream.title.trimLeft())) {
      continue;
    }
    if (stream.isLive && isStatusCurrent) {
      return FeaturedBroadcast(stream, FeaturedKind.live, url);
    }
    final starts = stream.startDate;
    if (stream.isUpcoming && (starts == null || !starts.isBefore(now))) {
      // Prefer a dated event when the feed also has an undated broadcast.
      if (upcoming == null ||
          (upcoming.stream.startDate == null && starts != null)) {
        upcoming = FeaturedBroadcast(stream, FeaturedKind.upcoming, url);
      }
    }
  }
  if (upcoming != null) return upcoming;
  for (final replay in replays) {
    final url = replay.safeUrl;
    if (url != null && !_testBroadcastTitle.hasMatch(replay.title.trimLeft())) {
      return FeaturedBroadcast(replay, FeaturedKind.replay, url);
    }
  }
  return null;
}
