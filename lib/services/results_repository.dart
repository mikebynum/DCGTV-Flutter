import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/json_snapshot_cache.dart';
import '../models/dcg_result.dart';

class ResultsRepository extends ChangeNotifier {
  ResultsRepository({DcgApiClient? api, DateTime Function()? now})
      : _api = api ?? DcgApiClient(),
        _now = now ?? DateTime.now;

  static const _cache = JsonSnapshotCache('dcgtv.results.snapshot');
  final DcgApiClient _api;
  final DateTime Function() _now;

  List<DcgResult> _results = const [];
  List<DcgResult> get results => _results;
  bool refreshFailed = false;
  bool get isLoading => _request != null;

  Future<void>? _request;
  DateTime? _lastAttempt;
  bool _disposed = false;

  Future<void> refresh({bool force = false}) async {
    if (_disposed) return;
    if (_request != null) return _request!;
    final now = _now();
    final last = _lastAttempt;
    if (!force &&
        last != null &&
        !now.isBefore(last) &&
        now.difference(last) < const Duration(minutes: 1)) {
      return;
    }
    _lastAttempt = now;
    final request = _fetch(loadSaved: last == null);
    _request = request;
    notifyListeners();
    try {
      await request;
    } finally {
      _request = null;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _fetch({required bool loadSaved}) async {
    if (loadSaved) {
      final snapshot = await _cache.load();
      if (_disposed) return;
      if (snapshot != null) {
        try {
          _results = _parse(snapshot.data);
          notifyListeners();
        } catch (error) {
          debugPrint('Could not read the saved results: $error');
        }
      }
    }

    final Map<String, dynamic> response;
    try {
      response = await _api.getSnapshot('results', _now());
      if (_disposed) return;
      _results = _parse(response);
      refreshFailed = false;
    } catch (error) {
      if (_disposed) return;
      refreshFailed = true;
      debugPrint('Could not refresh results: $error');
      return;
    }
    try {
      await _cache.save(response, _now());
    } catch (error) {
      debugPrint('Could not save results: $error');
    }
  }

  List<DcgResult> _parse(Map<String, dynamic> data) {
    final raw = data['results'];
    if (raw is! List) throw const FormatException('Expected a results list');
    final scores = raw.map(DcgResult.tryParse).whereType<DcgResult>().toList()
      ..sort((a, b) {
        final left = a.date;
        final right = b.date;
        if (left == null) return right == null ? 0 : 1;
        if (right == null) return -1;
        return right.compareTo(left);
      });
    return List.unmodifiable(scores);
  }

  @override
  void dispose() {
    _disposed = true;
    _api.close();
    super.dispose();
  }
}
