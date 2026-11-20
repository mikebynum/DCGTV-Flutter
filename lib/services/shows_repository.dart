import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/show_episode.dart';

class ShowsRepository extends ChangeNotifier {
  ShowsRepository({DcgApiClient? api, DateTime Function()? now})
      : _api = api ?? DcgApiClient(),
        _now = now ?? DateTime.now;

  final DcgApiClient _api;
  final DateTime Function() _now;
  final _episodes = <ShowSeries, List<ShowEpisode>>{};
  final _unavailable = <ShowSeries>{};

  Future<void>? _request;
  DateTime? _lastAttempt;
  bool _disposed = false;
  bool hasLoaded = false;
  bool refreshFailed = false;
  bool get isLoading => _request != null;

  List<ShowEpisode> episodes(ShowSeries series) =>
      _episodes[series] ?? const [];
  bool isUnavailable(ShowSeries series) => _unavailable.contains(series);

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
    final request = _fetch(now);
    _request = request;
    notifyListeners();
    try {
      await request;
    } finally {
      _request = null;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _fetch(DateTime now) async {
    try {
      final data = await _api.getSnapshot('videos', now);
      if (_disposed) return;
      final playlists = data['playlists'];
      if (playlists is! Map<String, dynamic>) {
        throw const FormatException('Expected a playlists object');
      }
      final errors = data['errors'];
      final playlistErrors = errors is Map<String, dynamic> ? errors : const {};
      final generalError = playlistErrors.containsKey('general');

      _unavailable.clear();
      for (final series in ShowSeries.values) {
        final raw = playlists[series.feedKey];
        final videos = raw is List
            ? raw.map(ShowEpisode.tryParse).whereType<ShowEpisode>().toList()
            : <ShowEpisode>[];
        final unavailable = generalError ||
            playlistErrors.containsKey(series.feedKey) ||
            raw is! List ||
            (raw.isNotEmpty && videos.isEmpty);
        if (unavailable) {
          _unavailable.add(series);
          if (videos.isEmpty) continue;
        }
        videos.sort(_newestFirst);
        _episodes[series] = List.unmodifiable(videos);
      }
      hasLoaded = true;
      refreshFailed = generalError;
    } catch (error) {
      if (_disposed) return;
      debugPrint('Could not refresh the shows: $error');
      refreshFailed = true;
    }
  }

  static int _newestFirst(ShowEpisode a, ShowEpisode b) {
    final left = a.publishedAt;
    final right = b.publishedAt;
    if (left == null) return right == null ? a.id.compareTo(b.id) : 1;
    if (right == null) return -1;
    final order = right.compareTo(left);
    return order == 0 ? a.id.compareTo(b.id) : order;
  }

  @override
  void dispose() {
    _disposed = true;
    _api.close();
    super.dispose();
  }
}
