import 'dart:convert';

import 'package:dcgtv/core/api_client.dart';
import 'package:dcgtv/features/home/home_highlights.dart';
import 'package:dcgtv/features/home/home_screen.dart';
import 'package:dcgtv/models/dcg_game.dart';
import 'package:dcgtv/models/dcg_stream.dart';
import 'package:dcgtv/services/games_repository.dart';
import 'package:dcgtv/services/results_repository.dart';
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
        {String? status, String sport = 'Girls Basketball'}) =>
    {
      'id': title,
      'title': title,
      'sport': sport,
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

  test('next three games are chronological and respect favorite sports', () {
    final events = [
      _gameJson('Later game', _future.add(const Duration(hours: 2))),
      _gameJson('Earlier game', _past),
      _gameJson('Postponed game', _now, status: 'POSTPONED'),
      _gameJson('Canceled game', _now, status: 'Cancelled'),
      _gameJson('Undated game', null),
      _gameJson('Next game', _future),
      _gameJson('Wrestling', _future.add(const Duration(minutes: 5)),
          sport: 'Girls Wrestling'),
      _gameJson('Other game', _future.add(const Duration(minutes: 10))),
    ].map(DcgGame.fromJson);

    expect(upcomingMustangGames(events, _now).map((game) => game.title),
        ['Next game', 'Wrestling', 'Other game']);
    expect(
        upcomingMustangGames(events, _now, favoriteSports: {'Girls Basketball'})
            .map((game) => game.title),
        ['Next game', 'Other game', 'Later game']);
    expect(upcomingMustangGames(events, _future.add(const Duration(days: 1))),
        isEmpty);
  });

  test('fallback broadcast requires a unique game and a matching sport', () {
    final game = DcgGame.fromJson(
        {..._gameJson('Ballard vs DCG', _future), 'dcgtv_stream': null});
    final matching = _stream(
        'Ballard at DCG Girls Varsity Basketball', 'upcoming',
        start: _future);
    final wrong = _stream('Ballard at DCG Boys Varsity Basketball', 'upcoming',
        start: _future);
    expect(
        matchGameBroadcast(game, [game], [wrong, matching]), matching.safeUrl);
    final ambiguous = DcgGame.fromJson(
        {..._gameJson('DCG at Ballard', _future), 'dcgtv_stream': null});
    expect(matchGameBroadcast(game, [game, ambiguous], [matching]), isNull);
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

  testWidgets(
      'shows Home links, saves favorites, and displays verified results',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final games = GamesRepository(
      now: () => _now,
      api: DcgApiClient(
          client: MockClient((_) async => http.Response(
                jsonEncode({
                  'games': [
                    _gameJson('Ballard vs DCG', _future),
                    _gameJson('Wrestling Invitational', _future,
                        sport: 'Girls Wrestling'),
                  ]
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
    final results = ResultsRepository(
      api: DcgApiClient(client: MockClient((request) async {
        expect(request.url.path, '/wp-json/dcg/v1/results');
        return http.Response(
            jsonEncode({
              'results': [
                {
                  'title': 'Girls Basketball: DCG vs North Polk (Varsity)',
                  'sport': 'Girls Basketball',
                  'level': 'Varsity',
                  'dcg_score': 50,
                  'opponent_score': 42,
                  'status': 'FINAL',
                  'start': _past.toIso8601String(),
                },
                {
                  'title': 'Incomplete game',
                  'sport': 'Girls Basketball',
                  'level': 'Varsity',
                  'dcg_score': 9,
                  'opponent_score': 5,
                  'status': 'live',
                  'start': _now.toIso8601String(),
                },
              ],
            }),
            200);
      })),
    );
    addTearDown(results.dispose);
    await Future.wait(
        [streams.initialize(), games.refresh(), results.refresh()]);
    expect(results.results.single.title, 'DCG vs North Polk');

    var watchOpened = false;
    var scheduleOpened = false;
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        streams: streams,
        games: games,
        results: results,
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
        scrollable: scroller, continuous: true);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('Ballard Pregame'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Full schedule'), 150,
        scrollable: scroller, continuous: true);
    await tester.tap(find.text('Full schedule'));
    expect(scheduleOpened, isTrue);
    await tester.scrollUntilVisible(find.text('Ballard vs DCG'), 150,
        scrollable: scroller, continuous: true);
    await tester.scrollUntilVisible(find.text('Watch on DCGTV').first, 140,
        scrollable: scroller, continuous: true);
    expect(find.text('Watch on DCGTV'), findsWidgets);
    await tester.scrollUntilVisible(
        find.text('Visit the DCG Booster Club'), 150,
        scrollable: scroller, continuous: true);
    expect(find.text('DCG 50–42 · Win'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Choose Favorite Sports'), -150,
        scrollable: scroller, continuous: true);
    await tester.tap(find.text('Choose Favorite Sports'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Girls Wrestling').last);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    final preferences = await SharedPreferences.getInstance();
    expect(
        preferences.getStringList('dcgtv.favoriteSports'), ['Girls Wrestling']);
    await tester.scrollUntilVisible(find.text('Wrestling Invitational'), 140,
        scrollable: scroller, continuous: true);
    expect(find.text('Ballard vs DCG'), findsNothing);
  });
}
