import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/stream_cache.dart';
import '../models/dcg_stream.dart';

class StreamsRepository extends ChangeNotifier {
  StreamsRepository({
    DcgApiClient? api,
    StreamCache? cache,
    DateTime Function()? now,
  })  : _api = api ?? DcgApiClient(),
        _cache = cache ?? StreamCache(),
        _now = now ?? DateTime.now;

  final DcgApiClient _api;
  final StreamCache _cache;
  final DateTime Function() _now;
  static const minimumRefreshInterval = Duration(seconds: 60);
  static const maximumStatusAge = Duration(seconds: 120);

  List<DcgStream> streams = [];
  List<DcgStream> replays = [];
  bool isLoading = false;
  bool isStatusCurrent = false;
  String? errorMessage;
  DateTime? lastUpdated;
  DateTime? _lastAttempt;
  Future<void>? _request;
  bool _disposed = false;

  static bool statusIsCurrent(DateTime? updated, DateTime now) {
    if (updated == null) return false;
    final age = now.difference(updated);
    return !age.isNegative && age < maximumStatusAge;
  }

  Future<void> initialize() async {
    final cached = await _cache.load();
    if (_disposed) return;
    if (cached != null && lastUpdated == null) {
      _apply(cached.response);
      lastUpdated = cached.response.updatedAt ?? cached.savedAt;
      notifyListeners();
    }
    await refresh();
  }

  void expireStatusIfNeeded() {
    if (isStatusCurrent && !statusIsCurrent(lastUpdated, _now())) {
      isStatusCurrent = false;
      notifyListeners();
    }
  }

  Future<void> refresh({bool force = false}) async {
    if (_disposed) return;
    expireStatusIfNeeded();
    if (_request != null) return _request!;

    final now = _now();
    if (!force && _lastAttempt != null) {
      final elapsed = now.difference(_lastAttempt!);
      if (!elapsed.isNegative && elapsed < minimumRefreshInterval) return;
    }
    _lastAttempt = now;
    isLoading = true;
    final request = _fetch();
    _request = request;
    notifyListeners();
    try {
      await request;
    } finally {
      _request = null;
      isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _fetch() async {
    final StreamResponse response;
    try {
      response = StreamResponse.fromJson(
        await _api.getSnapshot('streams', _now()),
      );
    } catch (error) {
      if (_disposed) return;
      isStatusCurrent = false;
      errorMessage = error.toString();
      return;
    }

    if (_disposed) return;
    final receivedAt = _now();
    _apply(response);
    lastUpdated = response.updatedAt ?? receivedAt;
    isStatusCurrent = response.stale == false &&
        statusIsCurrent(response.updatedAt, receivedAt);
    errorMessage = null;
    notifyListeners();

    try {
      await _cache.save(response, receivedAt);
    } catch (error) {
      debugPrint('Could not save the DCGTV broadcast cache: $error');
    }
  }

  void _apply(StreamResponse response) {
    streams = response.streams.where((s) => s.isLive || s.isUpcoming).toList()
      ..sort((a, b) {
        if (a.isLive != b.isLive) return a.isLive ? -1 : 1;
        return _compareStartDates(a, b);
      });
    replays = response.replays.toList()
      ..sort((a, b) => _compareStartDates(a, b, newestFirst: true));
  }

  int _compareStartDates(
    DcgStream a,
    DcgStream b, {
    bool newestFirst = false,
  }) {
    final left = a.startDate;
    final right = b.startDate;
    if (left == null) return right == null ? 0 : 1;
    if (right == null) return -1;
    return newestFirst ? right.compareTo(left) : left.compareTo(right);
  }

  @override
  void dispose() {
    _disposed = true;
    _api.close();
    super.dispose();
  }
}
