import 'dart:convert';

import 'package:dcgtv/core/api_client.dart';
import 'package:dcgtv/features/home/home_highlights.dart';
import 'package:dcgtv/features/home/home_screen.dart';
import 'package:dcgtv/models/dcg_game.dart';
import 'package:dcgtv/models/dcg_stream.dart';
import 'package:dcgtv/services/games_repository.dart';
import 'package:dcgtv/services/streams_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime.utc(2026, 11, 20, 18);
final _future = _now.add(const Duration(hours: 1));
final _past = _now.subtract(const Duration(hours: 1));

Map<String, Object?> _gameJson(String title, DateTime? start,
        {String? status}) =>
    {
      'id': title,
      'title': title,
      'sport': 'Girls Basketball',
      'level': 'Varsity',
      'start': start?.toIso8601String(),
      'location': 'DCG Meadows Main Gym',
      'status': status,
      'dcgtv_stream': {'url': 'https://www.youtube.com/watch?v=game'},
    };

DcgStream _stream(String title, String status,
        {DateTime? start, String? url}) =>
    DcgStream(
      id: title,
      title: title,
      status: status,
      thumbnail: '',
      url: url ?? 'https://www.youtube.com/watch?v=game',
      scheduledStart: start?.toIso8601String(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('next game skips past, undated, canceled and postponed games', () {
    final events = [
      _gameJson('Later game', _future.add(const Duration(hours: 2))),
      _gameJson('Earlier game', _past),
      _gameJson('Postponed game', _now, status: 'POSTPONED'),
      _gameJson('Canceled game', _now, status: 'Cancelled'),
      _gameJson('Undated game', null),
      _gameJson('Next game', _future),
    ].map(DcgGame.fromJson);

    expect(nextScheduledGame(events, _now)?.title, 'Next game');
    expect(nextScheduledGame(events, _future.add(const Duration(days: 1))),
        isNull);
  });

  test('only verified live broadcasts outrank the next upcoming stream', () {
    final upcoming = _stream('Upcoming game', 'upcoming', start: _future);
    final live = _stream('Live game', 'live', start: _past);
    final broadcasts = [
      _stream(' [TEST] broadcast', 'live'),
      _stream('Test!!', 'live'),
      _stream('Unsafe live', 'live', url: 'http://example.org/live'),
      live,
      _stream('Already started', 'upcoming', start: _past),
      upcoming,
      _stream('Undated broadcast', 'upcoming'),
    ];
    final verified = selectFeaturedBroadcast(
      streams: broadcasts,
      replays: [],
      isStatusCurrent: true,
      now: _now,
    );
    expect(verified?.kind, FeaturedKind.live);
    expect(verified?.stream, live);
    final unverified = selectFeaturedBroadcast(
      streams: broadcasts,
      replays: [],
      isStatusCurrent: false,
      now: _now,
    );
    expect(unverified?.kind, FeaturedKind.upcoming);
    expect(unverified?.stream, upcoming);
  });

  test('uses the newest playable replay when no current broadcast qualifies',
      () {
    final newest = _stream('Last game', 'completed', start: _past);
    final feature = selectFeaturedBroadcast(
      streams: [_stream('Previously live', 'live')],
      replays: [
        _stream('Test stream', 'completed'),
        _stream('Broken link', 'completed', url: 'javascript:alert(1)'),
        newest,
        _stream('Older game', 'completed'),
      ],
      isStatusCurrent: false,
      now: _now,
    );
    expect(feature?.kind, FeaturedKind.replay);
    expect(feature?.stream, newest);
  });

  testWidgets('shows the next game, a verified LIVE badge, and navigation',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final games = GamesRepository(
      now: () => _now,
      api: DcgApiClient(
          client: MockClient((_) async => http.Response(
                jsonEncode({
                  'games': [_gameJson('Ballard vs DCG', _future)]
                }),
                200,
              ))),
    );
    addTearDown(games.dispose);
    final streams = StreamsRepository(
      now: () => _now,
      api: DcgApiClient(
          client: MockClient((_) async => http.Response(
                jsonEncode(StreamResponse(
                  'DCGTV',
                  [_stream('Ballard Pregame', 'live')],
                  [],
                  updatedAt: _now,
                  stale: false,
                ).toJson()),
                200,
              ))),
    );
    addTearDown(streams.dispose);
    await Future.wait([streams.initialize(), games.refresh()]);

    var watchOpened = false;
    var scheduleOpened = false;
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        streams: streams,
        games: games,
        onShowWatch: () => watchOpened = true,
        onShowSchedule: () => scheduleOpened = true,
        now: () => _now,
      ),
    ));
    await tester.pumpAndSettle();
    final scroller = find.byType(Scrollable);
    expect(find.text('Featured Broadcast'), findsOneWidget);
    await tester.tap(find.text('All broadcasts'));
    expect(watchOpened, isTrue);
    await tester.scrollUntilVisible(find.text('Watch Live'), 150,
        scrollable: scroller);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('Ballard Pregame'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Full schedule'), 150,
        scrollable: scroller);
    await tester.tap(find.text('Full schedule'));
    expect(scheduleOpened, isTrue);
    await tester.scrollUntilVisible(find.text('Ballard vs DCG'), 150,
        scrollable: scroller);
    expect(find.text('Watch on DCGTV'), findsNothing);
  });
}
