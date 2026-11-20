import 'package:flutter/material.dart';

import '../../core/presentation.dart';
import '../../models/show_episode.dart';
import '../../services/shows_repository.dart';
import '../watch/broadcast_thumbnail.dart';

final _channelUrl = Uri.https('www.youtube.com', '/@DCGActivities/videos');

class ShowsScreen extends StatelessWidget {
  const ShowsScreen({super.key, required this.repository});

  final ShowsRepository repository;

  Future<void> _refresh() => repository.refresh(force: true);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: repository,
        builder: (context, child) => Scaffold(
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Semantics(
                    header: true,
                    child: Image.asset(
                      'assets/shows/DCGTVShowsHeader.png',
                      semanticLabel:
                          'DCGTV Originals. Presented by Charter Bank.',
                      fit: BoxFit.fitWidth,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (repository.isLoading)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Updating shows',
                    ),
                  if (repository.refreshFailed)
                    _RefreshNotice(
                      message: 'Couldn’t refresh shows.',
                      onRetry: repository.isLoading ? null : _refresh,
                    ),
                  for (final series in ShowSeries.values)
                    _SeriesCard(
                      series: series,
                      count: repository.episodes(series).length,
                      unavailable: repository.isUnavailable(series),
                      hasLoaded: repository.hasLoaded,
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => _EpisodesScreen(
                            series: series,
                            repository: repository,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => openInAppLink(context, _channelUrl),
                    style: FilledButton.styleFrom(
                      backgroundColor: dcgRed,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.ondemand_video),
                    label: const Text('Browse All DCGTV Videos'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _SeriesCard extends StatelessWidget {
  const _SeriesCard({
    required this.series,
    required this.count,
    required this.unavailable,
    required this.hasLoaded,
    required this.onTap,
  });

  final ShowSeries series;
  final int count;
  final bool unavailable;
  final bool hasLoaded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final icon = switch (series) {
      ShowSeries.fullGallop => Icons.mic,
      ShowSeries.seniorSpotlight => Icons.star,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SizedBox.square(
                  dimension: 44,
                  child: Icon(icon, color: colors.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(series.title, style: theme.textTheme.titleMedium),
                    Text(series.description, style: theme.textTheme.bodySmall),
                    if (hasLoaded)
                      Text(
                        unavailable && count == 0
                            ? 'Episodes unavailable'
                            : count == 1
                                ? '1 episode'
                                : '$count episodes',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.primary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodesScreen extends StatelessWidget {
  const _EpisodesScreen({required this.series, required this.repository});

  final ShowSeries series;
  final ShowsRepository repository;

  Future<void> _refresh() => repository.refresh(force: true);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: repository,
        builder: (context, child) {
          final episodes = repository.episodes(series);
          final unavailable =
              repository.refreshFailed || repository.isUnavailable(series);
          return Scaffold(
            appBar: AppBar(title: Text(series.title)),
            body: SafeArea(
              top: false,
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      sliver: SliverList.list(
                        children: [
                          Text(
                            series.description,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          if (repository.isLoading)
                            const LinearProgressIndicator(
                              semanticsLabel: 'Updating episodes',
                            ),
                          if (unavailable)
                            _RefreshNotice(
                              message: episodes.isEmpty
                                  ? 'Couldn’t load episodes.'
                                  : 'Couldn’t refresh episodes. Showing the last loaded list.',
                              onRetry: repository.isLoading ? null : _refresh,
                            )
                          else if (episodes.isEmpty && repository.hasLoaded)
                            const Text('No public episodes are available yet.'),
                        ],
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList.builder(
                        itemCount: episodes.length,
                        itemBuilder: (context, index) =>
                            _EpisodeCard(episode: episodes[index]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({required this.episode});

  final ShowEpisode episode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = episode.publishedAt;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(episode.title, style: theme.textTheme.titleSmall),
        if (date != null)
          Text(
            MaterialLocalizations.of(context).formatShortDate(date.toLocal()),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        hint: 'Opens this episode on YouTube',
        child: InkWell(
          onTap: () => openInAppLink(context, episode.url),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(builder: (context, constraints) {
              final thumbnail = BroadcastThumbnail(url: episode.thumbnail);
              if (constraints.maxWidth < 260 ||
                  MediaQuery.textScalerOf(context).scale(14) > 21) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 160, child: thumbnail),
                    const SizedBox(height: 8),
                    details,
                  ],
                );
              }
              return Row(
                children: [
                  SizedBox(width: 104, child: thumbnail),
                  const SizedBox(width: 12),
                  Expanded(child: details),
                  const SizedBox(width: 8),
                  Icon(Icons.play_circle_outline,
                      color: theme.colorScheme.primary),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _RefreshNotice extends StatelessWidget {
  const _RefreshNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          if (onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
        ],
      );
}
