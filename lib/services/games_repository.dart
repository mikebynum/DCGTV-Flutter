import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/json_snapshot_cache.dart';
import '../models/dcg_game.dart';

class GamesRepository extends ChangeNotifier {
  GamesRepository({DcgApiClient? api, DateTime Function()? now})
      : _api = api ?? DcgApiClient(),
        _now = now ?? DateTime.now;

  static const _cache = JsonSnapshotCache('dcgtv.games.snapshot');
  static const _minimumRefreshInterval = Duration(minutes: 1);
  final DcgApiClient _api;
  final DateTime Function() _now;

  List<DcgGame> _games = const [];
  List<DcgGame> get games => _games;
  DateTime? lastUpdated;
  bool showingSaved = false;
  bool refreshFailed = false;
  bool get isLoading => _request != null;

  Future<void>? _request;
  DateTime? _lastAttempt;
  bool _disposed = false;

  Future<void> refresh({bool force = false}) async {
    if (_disposed) return;
    if (_request != null) return _request!;

    final now = _now();
    final elapsed = _lastAttempt == null ? null : now.difference(_lastAttempt!);
    if (!force &&
        elapsed != null &&
        !elapsed.isNegative &&
        elapsed < _minimumRefreshInterval) {
      return;
    }

    final firstLoad = _lastAttempt == null;
    _lastAttempt = now;
    final request = _fetch(loadCache: firstLoad);
    _request = request;
    notifyListeners();
    try {
      await request;
    } finally {
      _request = null;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _fetch({required bool loadCache}) async {
    if (loadCache) {
      final snapshot = await _cache.load();
      if (_disposed) return;
      if (snapshot != null) {
        try {
          _games = _parseGames(snapshot.data);
          lastUpdated = _fetchedAt(snapshot.data) ?? snapshot.savedAt;
          showingSaved = true;
          notifyListeners();
        } on Object catch (error) {
          debugPrint('Could not read the saved schedule: $error');
        }
      }
    }

    final Map<String, dynamic> data;
    final List<DcgGame> games;
    try {
      data = await _api.getSnapshot('games', _now());
      games = _parseGames(data);
    } catch (error) {
      if (_disposed) return;
      refreshFailed = true;
      showingSaved = lastUpdated != null;
      debugPrint('Could not refresh the schedule: $error');
      return;
    }

    if (_disposed) return;
    final receivedAt = _now();
    _games = games;
    lastUpdated = _fetchedAt(data) ?? receivedAt;
    showingSaved = false;
    refreshFailed = false;
    try {
      await _cache.save(data, receivedAt);
    } catch (error) {
      debugPrint('Could not save the schedule: $error');
    }
  }

  DateTime? _fetchedAt(Map<String, dynamic> data) {
    final value = data['fetched_at'];
    return value is String ? DateTime.tryParse(value) : null;
  }

  List<DcgGame> _parseGames(Map<String, dynamic> data) {
    final events = data['games'];
    if (events is! List) throw const FormatException('Expected a games list');
    final games = events
        .map((event) => DcgGame.fromJson(event as Map<String, dynamic>))
        .toList()
      ..sort((a, b) {
        final left = a.start;
        final right = b.start;
        if (left == null) return right == null ? 0 : 1;
        if (right == null) return -1;
        final order = left.compareTo(right);
        return order == 0 ? a.id.compareTo(b.id) : order;
      });
    return List.unmodifiable(games);
  }

  @override
  void dispose() {
    _disposed = true;
    _api.close();
    super.dispose();
  }
}
