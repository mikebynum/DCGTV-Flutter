import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dcg_stream.dart';

class CachedStreams {
  final StreamResponse response;
  final DateTime savedAt;
  const CachedStreams(this.response, this.savedAt);
}

class StreamCache {
  static const _dataKey = 'dcgtv.streams.data';
  static const _savedKey = 'dcgtv.streams.savedAt';

  Future<CachedStreams?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_dataKey);
    final saved = prefs.getString(_savedKey);
    if (data == null || saved == null) return null;
    try {
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
    await prefs.setString(_dataKey, jsonEncode(response.toJson()));
    await prefs.setString(_savedKey, time.toIso8601String());
  }
}
