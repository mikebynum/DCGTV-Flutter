import 'dart:async';
import 'dart:convert';

import 'package:dcgtv/core/api_client.dart';
import 'package:dcgtv/features/schedule/schedule_screen.dart';
import 'package:dcgtv/models/dcg_game.dart';
import 'package:dcgtv/services/games_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ballard = {
  'id': 'ballard',
  'title': 'Girls Basketball: Ballard vs Dallas Center-Grimes (Varsity)',
  'sport': 'Girls Basketball',
  'level': 'Varsity',
  'start': '2026-11-20T19:30:00-06:00',
  'location': 'Dallas Center-Grimes High School DCG Meadows Main Gym',
  'status': 'CONFIRMED',
  'url': 'https://gobound.com/direct/comps/ballard/show',
  'dcgtv_stream': {'url': 'https://www.youtube.com/watch?v=S_cyNXwlpRs'},
};

const _away = {
  'id': 'away',
  'title': 'Girls Wrestling: DCG at North Metro (Invitational) (Varsity)',
  'sport': 'Girls Wrestling',
  'level': 'Varsity',
  'location': 'Urbandale High School South Gym',
  'status': 'POSTPONED',
  'external_stream': {
    'provider': 'Away broadcaster',
    'url': 'https://example.org/away',
    'note': 'A subscription may be required.',
  },
};

http.Response _feed(List<Map<String, Object?>> games) =>
    http.Response(jsonEncode({'games': games}), 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('maps Bound times, venues and server-resolved links', () {
    final game = DcgGame.fromJson(_ballard);
    expect(game.start, DateTime.utc(2026, 11, 21, 1, 30));
    expect(game.title, 'Ballard vs DCG');
    expect(game.location, 'DCG Meadows Main Gym');
    expect(game.status, isNull);
    expect(game.dcgtvUrl?.queryParameters['v'], 'S_cyNXwlpRs');

    final away = DcgGame.fromJson(_away);
    expect(away.title, 'DCG at North Metro (Invitational)');
    expect(away.status, 'POSTPONED');
    expect(away.location, 'Urbandale High School South Gym');
    expect(away.externalStream?.provider, 'Away broadcaster');
    expect(away.externalStream?.url, Uri.parse('https://example.org/away'));
  });

  test('rejects unsafe links and keeps games with unannounced dates', () {
    final game = DcgGame.fromJson({
      ..._ballard,
      'start': 'TBA',
      'url': 'http://gobound.com/game',
      'dcgtv_stream': {'url': 'https://user:password@example.org/watch'},
      'external_stream': {'url': 'javascript:alert(1)'},
    });
    expect(game.start, isNull);
    expect(game.detailsUrl, isNull);
    expect(game.dcgtvUrl, isNull);
    expect(game.externalStream, isNull);
  });

  test('loads saved games offline and coalesces overlapping refreshes',
      () async {
    final initial = GamesRepository(
      api: DcgApiClient(client: MockClient((request) async {
        expect(request.url.path, '/wp-json/dcg/v1/games');
        expect(request.url.queryParameters, contains('_dcgtv_refresh'));
        return _feed([_away, _ballard]);
      })),
    );
    addTearDown(initial.dispose);
    await initial.refresh();
    expect(initial.games.map((game) => game.id), ['ballard', 'away']);

    final network = Completer<http.Response>();
    var requests = 0;
    final reopened = GamesRepository(
      api: DcgApiClient(client: MockClient((_) async {
        requests++;
        if (requests == 1) return network.future;
        return _feed([_away]);
      })),
    );
    addTearDown(reopened.dispose);
    final cached = Completer<void>();
    reopened.addListener(() {
      if (reopened.showingSaved && !cached.isCompleted) cached.complete();
    });
    final startup = reopened.refresh();
    await cached.future;
    expect(reopened.games.first.dcgtvUrl, isNotNull);
    final manual = reopened.refresh(force: true);
    network.complete(http.Response('', 503));
    await Future.wait([startup, manual]);

    expect(requests, 1);
    expect(reopened.refreshFailed, isTrue);
    expect(reopened.showingSaved, isTrue);
    expect(reopened.games, hasLength(2));
    await reopened.refresh();
    expect(requests, 1);

    await reopened.refresh(force: true);
    expect(requests, 2);
    expect(reopened.games.single.id, 'away');
    expect(reopened.refreshFailed, isFalse);
    expect(reopened.showingSaved, isFalse);
  });

  testWidgets('shows upcoming games and filters to an away broadcast',
      (tester) async {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1)).toIso8601String();
    final yesterday = now.subtract(const Duration(days: 1)).toIso8601String();
    final repository = GamesRepository(
      api: DcgApiClient(
          client: MockClient((_) async => _feed([
                {..._ballard, 'start': tomorrow},
                _away,
                {
                  ..._ballard,
                  'id': 'past',
                  'title': 'Past game',
                  'start': yesterday
                },
              ]))),
    );
    addTearDown(repository.dispose);
    await repository.refresh();

    await tester.pumpWidget(
      MaterialApp(home: ScheduleScreen(active: true, repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ballard vs DCG'), findsOneWidget);
    expect(find.text('Watch on DCGTV'), findsOneWidget);
    expect(find.text('Past game'), findsNothing);

    await tester.enterText(find.byType(TextField), 'North Metro');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Ballard vs DCG'), findsNothing);
    expect(find.text('Date to be confirmed'), findsOneWidget);
    expect(find.text('DCG at North Metro (Invitational)'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Watch via Away broadcaster'),
        findsOneWidget);
    expect(find.text('A subscription may be required.'), findsOneWidget);
  });
}
