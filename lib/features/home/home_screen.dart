import 'package:flutter/material.dart';

import '../../core/presentation.dart';
import '../../services/games_repository.dart';
import '../../services/streams_repository.dart';
import '../schedule/game_card.dart';
import '../watch/broadcast_thumbnail.dart';
import 'home_highlights.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.streams,
    required this.games,
    required this.onShowWatch,
    required this.onShowSchedule,
    this.now = DateTime.now,
  });

  final StreamsRepository streams;
  final GamesRepository games;
  final VoidCallback onShowWatch;
  final VoidCallback onShowSchedule;
  final DateTime Function() now;

  Future<void> _refresh() => Future.wait([
        streams.refresh(force: true),
        games.refresh(force: true),
      ]);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([streams, games]),
        builder: (context, child) => _buildHome(context),
      );

  Widget _buildHome(BuildContext context) {
    final currentTime = now();
    final next = nextScheduledGame(games.games, currentTime);
    final featured = selectFeaturedBroadcast(
      streams: streams.streams,
      replays: streams.replays,
      isStatusCurrent: streams.isStatusCurrent,
      now: currentTime,
    );
    final loading = streams.isLoading || games.isLoading;
    final failed = streams.errorMessage != null || games.refreshFailed;

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
                    semanticsLabel: 'Updating games and broadcasts',
                  ),
                ),
              const SizedBox(height: 10),
              _HomeSectionHeading(
                title: 'Featured Broadcast',
                action: 'All broadcasts',
                onPressed: onShowWatch,
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
                title: 'Next Game',
                action: 'Full schedule',
                onPressed: onShowSchedule,
              ),
              if (next != null)
                GameCard(
                  game: next,
                  showDate: true,
                  showDcgTvLink: featured?.url != next.dcgtvUrl,
                )
              else if (!games.isLoading)
                _HomeMessage(
                  games.refreshFailed && games.lastUpdated == null
                      ? 'Couldn’t load upcoming games.'
                      : 'No upcoming games with a confirmed time.',
                ),
              if (games.showingSaved) const Text('Showing the saved schedule.'),
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
      color: const Color(0xFF191517),
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
                      : const Color(0xFF423438),
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
