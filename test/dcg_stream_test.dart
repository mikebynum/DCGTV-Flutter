import 'package:flutter_test/flutter_test.dart';
import 'package:dcgtv/models/dcg_stream.dart';
import 'package:dcgtv/services/streams_repository.dart';

void main() {
  final sample = {
    'channel': 'DCGTV',
    'streams': [
      {'id': 'one', 'title': 'DCG vs Ames', 'status': 'live',
       'thumbnail': 'https://example.com/thumbnail.jpg',
       'url': 'https://youtube.com/watch?v=123',
       'scheduled_start': '2026-11-17T18:00:00Z'},
    ],
  };

  test('decodes stream response without optional replays', () {
    final result = StreamResponse.fromJson(sample);
    expect(result.streams.single.isLive, true);
    expect(result.replays, isEmpty);
    expect(result.streams.single.startDate, isNotNull);
  });

  test('rejects non-HTTPS playback URLs', () {
    final json = Map<String, dynamic>.from(sample['streams'] as List == [] ? {} : (sample['streams'] as List).first as Map);
    json['url'] = 'javascript:alert(1)';
    expect(DcgStream.fromJson(json).safeUrl, isNull);
  });

  test('freshness expires after 120 seconds', () {
    final updated = DateTime.utc(2026, 11, 17, 12);
    expect(StreamsRepository.statusIsCurrent(updated,
      updated.add(const Duration(seconds: 119))), true);
    expect(StreamsRepository.statusIsCurrent(updated,
      updated.add(const Duration(seconds: 120))), false);
    expect(StreamsRepository.statusIsCurrent(updated,
      updated.subtract(const Duration(seconds: 1))), false);
  });
}
