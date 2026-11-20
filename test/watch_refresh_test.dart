import 'dart:async';
import 'dart:convert';

import 'package:dcgtv/core/api_client.dart';
import 'package:dcgtv/models/dcg_stream.dart';
import 'package:dcgtv/services/streams_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime.utc(2026, 11, 20, 16);

const _stream = {
  'id': 'game',
  'title': 'DCG Varsity Volleyball 10/27/26 @ 7pm (Class 5A Region 2 Final)',
  'scheduled_start': '2026-10-27T23:40:07Z',
  'status': 'live',
  'thumbnail': '',
  'url': 'https://www.youtube.com/watch?v=game',
};

Map<String, dynamic> _feed(DateTime? updatedAt, {bool stale = false}) => {
      'channel': 'DCGActivities',
      'updated_at': updatedAt?.toIso8601String(),
      'stale': stale,
      'streams': [_stream],
      'replays': [
        {..._stream, 'id': 'replay', 'status': 'completed'},
      ],
    };

http.Response _ok(Map<String, dynamic> data) =>
    http.Response(jsonEncode(data), 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('keeps tournament details when removing the embedded date and time', () {
    final stream = DcgStream.fromJson(_stream);
    expect(stream.displayTitle,
        'DCG Varsity Volleyball (Class 5A Region 2 Final)');
    final undated = DcgStream.fromJson({..._stream, 'scheduled_start': null});
    expect(undated.displayTitle, undated.title);
  });

  for (final (label, updatedAt, stale) in [
    ('stale', _now, true),
    ('expired', _now.subtract(StreamsRepository.maximumStatusAge), false),
    ('missing timestamp', null, false),
    ('future timestamp', _now.add(const Duration(seconds: 1)), false),
  ]) {
    test('$label feed keeps playback links and leaves LIVE unverified',
        () async {
      final repository = StreamsRepository(
        now: () => _now,
        api: DcgApiClient(
          client: MockClient((_) async => _ok(_feed(updatedAt, stale: stale))),
        ),
      );
      addTearDown(repository.dispose);

      await repository.initialize();

      expect(repository.isStatusCurrent, isFalse);
      expect(repository.streams.single.safeUrl, isNotNull);
      expect(repository.replays.single.id, 'replay');
    });
  }

  test('fresh network status expires from the server timestamp', () async {
    var now = _now;
    final serverTime = _now.subtract(const Duration(seconds: 75));
    final repository = StreamsRepository(
      now: () => now,
      api:
          DcgApiClient(client: MockClient((_) async => _ok(_feed(serverTime)))),
    );
    addTearDown(repository.dispose);

    await repository.initialize();
    expect(repository.isStatusCurrent, isTrue);
    expect(repository.lastUpdated, serverTime);

    now = now.add(const Duration(seconds: 45));
    repository.expireStatusIfNeeded();
    expect(repository.isStatusCurrent, isFalse);
  });

  test('serves disk cache offline and recovers with a forced refresh',
      () async {
    final initial = StreamsRepository(
      now: () => _now,
      api: DcgApiClient(client: MockClient((_) async => _ok(_feed(_now)))),
    );
    addTearDown(initial.dispose);
    await initial.initialize();
    expect(initial.isStatusCurrent, isTrue);

    var requests = 0;
    final request = Completer<http.Response>();
    final started = Completer<void>();
    final reopened = StreamsRepository(
      now: () => _now,
      api: DcgApiClient(client: MockClient((requestDetails) async {
        expect(requestDetails.url.path, '/wp-json/dcg/v1/streams');
        expect(requestDetails.url.queryParameters, contains('_dcgtv_refresh'));
        requests++;
        if (requests == 1) {
          started.complete();
          return request.future;
        }
        return _ok(_feed(_now));
      })),
    );
    addTearDown(reopened.dispose);

    final initialization = reopened.initialize();
    await started.future;
    expect(reopened.streams.single.id, 'game');
    expect(reopened.replays.single.safeUrl, isNotNull);
    expect(reopened.isStatusCurrent, isFalse);

    final manual = reopened.refresh(force: true);
    expect(requests, 1);
    request.complete(http.Response('', 503));
    await Future.wait([initialization, manual]);
    expect(reopened.errorMessage, isNotNull);
    expect(reopened.replays.single.id, 'replay');
    expect(reopened.isStatusCurrent, isFalse);

    await reopened.refresh();
    expect(requests, 1);
    await reopened.refresh(force: true);
    expect(requests, 2);
    expect(reopened.isStatusCurrent, isTrue);
    expect(reopened.errorMessage, isNull);
  });

  test('reads the legacy two-key broadcast cache when offline', () async {
    SharedPreferences.setMockInitialValues({
      'dcgtv.streams.data': jsonEncode(_feed(null)..remove('stale')),
      'dcgtv.streams.savedAt': _now.toIso8601String(),
    });
    final repository = StreamsRepository(
      now: () => _now,
      api: DcgApiClient(
        client: MockClient((_) async => throw http.ClientException('offline')),
      ),
    );
    addTearDown(repository.dispose);

    await repository.initialize();
    expect(repository.lastUpdated, _now);
    expect(repository.streams.single.id, 'game');
    expect(repository.isStatusCurrent, isFalse);
  });
}
