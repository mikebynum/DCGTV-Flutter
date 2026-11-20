import '../../models/dcg_game.dart';
import '../../models/dcg_stream.dart';

const _inactiveGameStatuses = {'canceled', 'cancelled', 'postponed'};
final _testBroadcastTitle =
    RegExp(r'^(?:\[test\]|test\b)', caseSensitive: false);

List<DcgGame> upcomingMustangGames(
  Iterable<DcgGame> games,
  DateTime now, {
  Set<String> favoriteSports = const {},
}) {
  final upcoming = games.where((game) {
    final start = game.start;
    return start != null &&
        !start.isBefore(now) &&
        !_inactiveGameStatuses.contains(game.status?.toLowerCase()) &&
        (favoriteSports.isEmpty || favoriteSports.contains(game.sport));
  }).toList()
    ..sort((a, b) {
      final order = a.start!.compareTo(b.start!);
      return order == 0 ? a.id.compareTo(b.id) : order;
    });
  return upcoming.take(3).toList();
}

Uri? matchGameBroadcast(
  DcgGame game,
  Iterable<DcgGame> schedule,
  Iterable<DcgStream> streams,
) {
  final candidates = streams
      .where((stream) =>
          stream.safeUrl != null &&
          !_testBroadcastTitle.hasMatch(stream.title.trimLeft()) &&
          _matchesGame(game, stream))
      .toList();
  if (candidates.length != 1) return null;
  final stream = candidates.single;
  return schedule.where((other) => _matchesGame(other, stream)).length == 1
      ? stream.safeUrl
      : null;
}

String _normalized(String text) => RegExp(r'[a-z0-9]+')
    .allMatches(text.toLowerCase())
    .map((match) => match.group(0)!)
    .join(' ');

bool _matchesGame(DcgGame game, DcgStream stream) {
  final gameStart = game.start;
  final streamStart = stream.startDate;
  if (gameStart == null ||
      streamStart == null ||
      (gameStart.difference(streamStart).abs() > const Duration(hours: 3)) ||
      _inactiveGameStatuses.contains(game.status?.toLowerCase())) {
    return false;
  }

  final teams =
      game.title.split(RegExp(r'\s+(?:vs\.?|at)\s+', caseSensitive: false));
  if (teams.length != 2) return false;
  final left = _normalized(teams.first.split('(').first);
  final right = _normalized(teams.last.split('(').first);
  final opponent = left == 'dcg'
      ? right
      : right == 'dcg'
          ? left
          : '';
  if (opponent.length < 4) return false;

  final sport = _normalized(game.sport);
  final coreSport = sport.replaceFirst(RegExp(r'^(?:boys|girls) '), '');
  final title = ' ${_normalized(stream.title)} ';
  if (!title.contains(' $opponent ') ||
      coreSport.isEmpty ||
      !title.contains(' $coreSport ')) {
    return false;
  }
  if (sport.startsWith('boys ') && title.contains(' girls ')) return false;
  if (sport.startsWith('girls ') && title.contains(' boys ')) return false;

  final level = _normalized(game.level);
  final juniorVarsity =
      title.contains(' junior varsity ') || title.contains(' jv ');
  if (juniorVarsity) return level == 'junior varsity' || level == 'jv';
  if (title.contains(' varsity ')) return level == 'varsity';
  return true;
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
