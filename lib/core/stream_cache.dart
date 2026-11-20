import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/dcg_stream.dart';
import 'json_snapshot_cache.dart';

class CachedStreams {
  final StreamResponse response;
  final DateTime savedAt;
  const CachedStreams(this.response, this.savedAt);
}

class StreamCache {
  static const _snapshot = JsonSnapshotCache('dcgtv.streams.snapshot');
  static const _dataKey = 'dcgtv.streams.data';
  static const _savedKey = 'dcgtv.streams.savedAt';

  Future<CachedStreams?> load() async {
    try {
      final snapshot = await _snapshot.load();
      if (snapshot != null) {
        return CachedStreams(
          StreamResponse.fromJson(snapshot.data),
          snapshot.savedAt,
        );
      }

      // Accept broadcasts saved by builds before the snapshot was introduced.
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_dataKey);
      final saved = prefs.getString(_savedKey);
      if (data == null || saved == null) return null;
      return CachedStreams(
        StreamResponse.fromJson(jsonDecode(data) as Map<String, dynamic>),
        DateTime.parse(saved),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(StreamResponse response, DateTime time) =>
      _snapshot.save(response.toJson(), time);
}
