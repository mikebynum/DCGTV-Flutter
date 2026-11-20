import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class JsonSnapshot {
  const JsonSnapshot(this.data, this.savedAt);

  final Map<String, dynamic> data;
  final DateTime savedAt;
}

class JsonSnapshotCache {
  const JsonSnapshotCache(this.key);

  final String key;

  Future<JsonSnapshot?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final snapshot = prefs.getString(key);
      if (snapshot == null) return null;
      final decoded = jsonDecode(snapshot) as Map<String, dynamic>;
      return JsonSnapshot(
        decoded['response'] as Map<String, dynamic>,
        DateTime.parse(decoded['savedAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(Map<String, dynamic> data, DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      key,
      jsonEncode({
        'response': data,
        'savedAt': time.toUtc().toIso8601String(),
      }),
    );
    if (!saved) throw StateError('Unable to save $key');
  }
}
