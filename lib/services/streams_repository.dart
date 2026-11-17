import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/stream_cache.dart';
import '../models/dcg_stream.dart';

class StreamsRepository extends ChangeNotifier {
  StreamsRepository({
    DcgApiClient? api, StreamCache? cache, DateTime Function()? now,
  }) : _api = api ?? DcgApiClient(),
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
  bool _disposed = false;

  static bool statusIsCurrent(DateTime? updated, DateTime now) {
    if (updated == null) return false;
    final age = now.difference(updated);
    return !age.isNegative && age < maximumStatusAge;
  }

  Future<void> initialize() async {
    final cached = await _cache.load();
    if (_disposed) return;
    if (cached != null) {
      _apply(cached.response);
      lastUpdated = cached.savedAt;
      isStatusCurrent = false; // Disk cache never proves a stream is live.
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
    expireStatusIfNeeded();
    if (isLoading || _disposed) return;
    final now = _now();
    if (!force && _lastAttempt != null) {
      final elapsed = now.difference(_lastAttempt!);
      if (!elapsed.isNegative && elapsed < minimumRefreshInterval) return;
    }
    _lastAttempt = now;
    isLoading = true;
    notifyListeners();
    try {
      final response = StreamResponse.fromJson(await _api.getObject('streams'));
      if (_disposed) return;
      _apply(response);
      lastUpdated = _now();
      isStatusCurrent = true;
      errorMessage = null;
      await _cache.save(response, lastUpdated!);
    } catch (error) {
      if (_disposed) return;
      isStatusCurrent = false;
      errorMessage = error.toString();
    } finally {
      if (!_disposed) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  void _apply(StreamResponse response) {
    streams = response.streams.where((s) => s.isLive || s.isUpcoming).toList()
      ..sort((a, b) {
        if (a.isLive != b.isLive) return a.isLive ? -1 : 1;
        final left = a.startDate;
        final right = b.startDate;
        if (left == null && right == null) return 0;
        if (left == null) return 1;
        if (right == null) return -1;
        return left.compareTo(right);
      });
    replays = response.replays;
  }

  @override
  void dispose() {
    _disposed = true;
    _api.close();
    super.dispose();
  }
}
