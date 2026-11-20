import 'dart:convert';

import 'package:dcgtv/core/api_client.dart';
import 'package:dcgtv/features/shows/shows_screen.dart';
import 'package:dcgtv/models/show_episode.dart';
import 'package:dcgtv/services/shows_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _gallop = {
  'id': 'yvdlyw1wkmc',
  'title': 'Mustang Full Gallop 10-28-26',
  'thumbnail': '',
  'published_at': '2026-10-28T23:38:18Z',
  'url': 'https://www.youtube.com/watch?v=yvdlyw1wkmc',
};
const _spotlight = {
  'id': '39UbVRf71yk',
  'title': 'Senior Spotlight - Avery Edgington',
  'thumbnail': '',
  'published_at': '2026-10-28T21:50:04Z',
  'url': 'https://youtu.be/39UbVRf71yk',
};

http.Response _feed(Map<String, Object?> playlists,
        {Object errors = const []}) =>
    http.Response(jsonEncode({'playlists': playlists, 'errors': errors}), 200);

void main() {
  test('only offers valid HTTPS YouTube episode URLs', () {
    expect(
        ShowEpisode.tryParse(_gallop)?.url.queryParameters['v'], 'yvdlyw1wkmc');
    expect(ShowEpisode.tryParse(_spotlight)?.url.host, 'youtu.be');
    for (final url in [
      'http://youtube.com/watch?v=yvdlyw1wkmc',
      'https://youtube.com.example.org/watch?v=yvdlyw1wkmc',
      'https://user@youtube.com/watch?v=yvdlyw1wkmc',
      'https://www.youtube.com/redirect?q=https://example.org',
      'https://www.youtube.com/watch?v=',
    ]) {
      expect(ShowEpisode.tryParse({..._gallop, 'url': url}), isNull,
          reason: url);
    }
  });

  test('sorts episodes and keeps the last list for a failed playlist',
      () async {
    var attempts = 0;
    final repository = ShowsRepository(
      api: DcgApiClient(client: MockClient((request) async {
        expect(request.url.path, '/wp-json/dcg/v1/videos');
        attempts++;
        switch (attempts) {
          case 1:
            return _feed({
              'full_gallop': [
                {
                  ..._gallop,
                  'id': 'older',
                  'published_at': '2026-10-20T23:38:18Z'
                },
                _gallop,
                {..._gallop, 'id': 'undated', 'published_at': null},
                {'id': 'missing fields'},
              ],
              'senior_spotlight': [_spotlight],
            });
          case 2:
            return _feed(
              {'full_gallop': [], 'senior_spotlight': []},
              errors: {'full_gallop': 'Unavailable'},
            );
          default:
            return http.Response('', 503);
        }
      })),
    );
    addTearDown(repository.dispose);

    await repository.refresh();
    expect(
        repository.episodes(ShowSeries.fullGallop).map((episode) => episode.id),
        ['yvdlyw1wkmc', 'older', 'undated']);
    expect(repository.episodes(ShowSeries.seniorSpotlight), hasLength(1));

    await repository.refresh();
    expect(attempts, 1);
    await repository.refresh(force: true);
    expect(repository.isUnavailable(ShowSeries.fullGallop), isTrue);
    expect(repository.episodes(ShowSeries.fullGallop), hasLength(3));
    expect(repository.isUnavailable(ShowSeries.seniorSpotlight), isFalse);
    expect(repository.episodes(ShowSeries.seniorSpotlight), isEmpty);

    await repository.refresh(force: true);
    expect(repository.refreshFailed, isTrue);
    expect(repository.episodes(ShowSeries.fullGallop), hasLength(3));
  });

  testWidgets('opens a dedicated episode list for the selected category',
      (tester) async {
    final repository = ShowsRepository(
      api: DcgApiClient(
          client: MockClient((_) async => _feed({
                'full_gallop': [_gallop],
                'senior_spotlight': [_spotlight],
              }))),
    );
    addTearDown(repository.dispose);
    await repository.refresh();

    await tester
        .pumpWidget(MaterialApp(home: ShowsScreen(repository: repository)));
    await tester.pumpAndSettle();
    expect(find.text('Mustang Full Gallop'), findsOneWidget);
    expect(find.text('Senior Spotlight'), findsOneWidget);

    await tester.tap(find.text('Senior Spotlight'));
    await tester.pumpAndSettle();
    expect(find.text('Senior Spotlight - Avery Edgington'), findsOneWidget);
    expect(find.text('Mustang Full Gallop 10-28-26'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Mustang Full Gallop'), findsOneWidget);
  });
}
