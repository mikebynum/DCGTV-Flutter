import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/dcg_stream.dart';

class CachedStreams {
  final StreamResponse response;
  final DateTime savedAt;
  const CachedStreams(this.response, this.savedAt);
}

class StreamCache {
  static const _snapshotKey = 'dcgtv.streams.snapshot';
  static const _dataKey = 'dcgtv.streams.data';
  static const _savedKey = 'dcgtv.streams.savedAt';

  Future<CachedStreams?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final snapshot = prefs.getString(_snapshotKey);
      if (snapshot != null) {
        final decoded = jsonDecode(snapshot) as Map<String, dynamic>;
        return CachedStreams(
          StreamResponse.fromJson(decoded['response'] as Map<String, dynamic>),
          DateTime.parse(decoded['savedAt'] as String),
        );
      }

      // Accept broadcasts saved by builds before the snapshot was introduced.
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

  Future<void> save(StreamResponse response, DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      _snapshotKey,
      jsonEncode({
        'response': response.toJson(),
        'savedAt': time.toUtc().toIso8601String(),
      }),
    );
    if (!saved) throw StateError('Unable to save the broadcast cache');
  }
}
