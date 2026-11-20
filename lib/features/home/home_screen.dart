import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/presentation.dart';
import '../../services/games_repository.dart';
import '../../services/results_repository.dart';
import '../../services/streams_repository.dart';
import '../schedule/game_card.dart';
import '../watch/broadcast_thumbnail.dart';
import 'favorite_sports_picker.dart';
import 'home_highlights.dart';
import 'recent_results.dart';

final _boosterClubUrl = Uri.https('dcgboosterclub.com', '/');

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.streams,
    required this.games,
    required this.results,
    required this.onShowWatch,
    required this.onShowSchedule,
    this.now = DateTime.now,
  });

  final StreamsRepository streams;
  final GamesRepository games;
  final ResultsRepository results;
  final VoidCallback onShowWatch;
  final VoidCallback onShowSchedule;
  final DateTime Function() now;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _favoritesKey = 'dcgtv.favoriteSports';
  final _preferences = SharedPreferences.getInstance();
  Set<String> _favoriteSports = const {};
  bool _favoritesReady = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFavorites());
  }

  Future<void> _loadFavorites() async {
    try {
      final preferences = await _preferences;
      _favoriteSports =
          (preferences.getStringList(_favoritesKey) ?? []).toSet();
    } catch (error) {
      debugPrint('Could not load favorite sports: $error');
    }
    if (mounted) setState(() => _favoritesReady = true);
  }

  Future<void> _editFavorites() async {
    final sports = {
      ...widget.games.games
          .map((game) => game.sport)
          .where((sport) => sport.isNotEmpty),
      ..._favoriteSports,
    }.toList()
      ..sort();
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          FavoriteSportsPicker(sports: sports, selected: _favoriteSports),
    );
    if (!mounted || selected == null) return;

    setState(() => _favoriteSports = selected);
    try {
      final preferences = await _preferences;
      final saved = await preferences.setStringList(
        _favoritesKey,
        selected.toList()..sort(),
      );
      if (!saved) throw StateError('Could not save favorite sports');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Couldn’t save favorites on this device.')),
      );
    }
  }

  Future<void> _refresh() => Future.wait([
        widget.streams.refresh(force: true),
        widget.games.refresh(force: true),
        widget.results.refresh(force: true),
      ]);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable:
            Listenable.merge([widget.streams, widget.games, widget.results]),
        builder: (context, child) => _buildHome(context),
      );

  Widget _buildHome(BuildContext context) {
    final streams = widget.streams;
    final games = widget.games;
    final results = widget.results;
    final currentTime = widget.now();
    final upcoming = upcomingMustangGames(
      games.games,
      currentTime,
      favoriteSports: _favoriteSports,
    );
    final featured = selectFeaturedBroadcast(
      streams: streams.streams,
      replays: streams.replays,
      isStatusCurrent: streams.isStatusCurrent,
      now: currentTime,
    );
    final loading = streams.isLoading || games.isLoading || results.isLoading;
    final failed = streams.errorMessage != null ||
        games.refreshFailed ||
        results.refreshFailed;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Image.asset(
                'assets/home/DCGTVHomeHero.png',
                fit: BoxFit.fitWidth,
                semanticLabel: 'DCGTV',
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(
                    semanticsLabel: 'Updating games, broadcasts, and results',
                  ),
                ),
              const SizedBox(height: 10),
              _HomeSectionHeading(
                title: 'Featured Broadcast',
                action: 'All broadcasts',
                onPressed: widget.onShowWatch,
              ),
              if (featured != null)
                _FeaturedCard(broadcast: featured)
              else if (!streams.isLoading)
                _HomeMessage(
                  streams.errorMessage != null
                      ? 'Couldn’t load featured broadcasts.'
                      : 'No broadcasts available.',
                ),
              if (!streams.isStatusCurrent && streams.lastUpdated != null)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Live status is unverified.'),
                ),
              const SizedBox(height: 12),
              _HomeSectionHeading(
                title: 'Upcoming Mustang Games',
                action: 'Full schedule',
                onPressed: widget.onShowSchedule,
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _favoritesReady &&
                          (games.games.isNotEmpty || _favoriteSports.isNotEmpty)
                      ? _editFavorites
                      : null,
                  icon: Icon(
                      _favoriteSports.isEmpty ? Icons.star_border : Icons.star),
                  label: Text(_favoriteSports.isEmpty
                      ? 'Choose Favorite Sports'
                      : 'Edit Favorite Sports'),
                ),
              ),
              if (upcoming.isEmpty && !games.isLoading)
                _HomeMessage(
                  games.refreshFailed && games.lastUpdated == null
                      ? 'Couldn’t load upcoming games.'
                      : _favoriteSports.isEmpty
                          ? 'No upcoming games with a confirmed time.'
                          : 'No upcoming games in your favorite sports.',
                ),
              for (final game in upcoming)
                GameCard(
                  game: game,
                  showDate: true,
                  matchedBroadcastUrl: game.dcgtvUrl == null
                      ? matchGameBroadcast(game, games.games, streams.streams)
                      : null,
                ),
              if (games.showingSaved) const Text('Showing the saved schedule.'),
              const SizedBox(height: 16),
              RecentResults(repository: results),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  'Support DCGTV',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => openInAppLink(context, _boosterClubUrl),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Visit the DCG Booster Club'),
                ),
              ),
              if (failed && !loading)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeSectionHeading extends StatelessWidget {
  const _HomeSectionHeading({
    required this.title,
    required this.action,
    required this.onPressed,
  });

  final String title;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          TextButton(onPressed: onPressed, child: Text(action)),
        ],
      );
}

class _HomeMessage extends StatelessWidget {
  const _HomeMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(message),
        ),
      );
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.broadcast});

  final FeaturedBroadcast broadcast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stream = broadcast.stream;
    final kind = broadcast.kind;
    final date = stream.startDate;
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFF171819),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BroadcastThumbnail(url: stream.thumbnail),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: kind == FeaturedKind.live
                      ? dcgRed
                      : const Color(0xFF484B4D),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    kind.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              stream.displayTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (date != null)
              Text(
                localDateTime(context, date),
                style:
                    theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            const SizedBox(height: 4),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: dcgRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () => openInAppLink(context, broadcast.url),
              icon: Icon(kind == FeaturedKind.upcoming
                  ? Icons.event
                  : Icons.play_arrow),
              label: Text(kind.action),
            ),
          ],
        ),
      ),
    );
  }
}
