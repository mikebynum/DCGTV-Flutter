import 'package:flutter/material.dart';

import '../../core/presentation.dart';
import '../../models/dcg_stream.dart';
import '../../services/streams_repository.dart';
import 'broadcast_thumbnail.dart';

final _sponsorUrl = Uri.https('www.charterbanker.com', '/');
final _channelUrl = Uri.https('www.youtube.com', '/@DCGActivities/streams');

class WatchScreen extends StatelessWidget {
  const WatchScreen({super.key, required this.repository});

  final StreamsRepository repository;

  List<Widget> _section(
    BuildContext context,
    String title,
    IconData icon,
    List<DcgStream> streams,
    _BroadcastKind kind,
    String emptyMessage,
  ) =>
      [
        _SectionHeading(title: title, icon: icon),
        if (streams.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(emptyMessage),
            ),
          ),
        for (final stream in streams)
          _BroadcastCard(
            stream: stream,
            kind: kind,
            onOpen: (url) => openInAppLink(context, url),
          ),
        const SizedBox(height: 6),
      ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: repository,
        builder: (context, child) => _buildWatch(context),
      );

  Widget _buildWatch(BuildContext context) {
    final current = repository.isStatusCurrent;
    final updated = repository.lastUpdated;
    final live = repository.streams.where((stream) => stream.isLive).toList();
    final upcoming =
        repository.streams.where((stream) => stream.isUpcoming).toList();
    final hasBroadcastData = updated != null;
    final showSections = hasBroadcastData || !repository.isLoading;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => repository.refresh(force: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, 24 + MediaQuery.paddingOf(context).bottom),
            children: [
              Semantics(
                header: true,
                button: true,
                label:
                    'DCGTV. Watch Live and On-Demand. Presented by Charter Bank.',
                hint: 'Opens the Charter Bank website',
                onTap: () => openInAppLink(context, _sponsorUrl),
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => openInAppLink(context, _sponsorUrl),
                  child: Image.asset(
                    'assets/watch/DCGTVWatchHeader.png',
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (repository.isLoading)
                const LinearProgressIndicator(
                  semanticsLabel: 'Updating broadcasts',
                ),
              if (repository.errorMessage != null)
                Text(
                  hasBroadcastData
                      ? 'Couldn’t refresh. Showing saved broadcasts. Live status is unverified.'
                      : 'Couldn’t load broadcasts. Check your connection and retry.',
                )
              else if (!current && hasBroadcastData)
                const Text('Live status is unverified.'),
              if (updated != null)
                Text(
                  'Last updated ${localDateTime(context, updated)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (!current && !repository.isLoading)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => repository.refresh(force: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ),
              if (showSections) ...[
                ..._section(
                  context,
                  current ? 'Live Now' : 'Live Status Unverified',
                  Icons.sensors,
                  live,
                  current ? _BroadcastKind.live : _BroadcastKind.unverified,
                  current
                      ? 'Nothing live right now.'
                      : 'Live status is unavailable.',
                ),
                if (hasBroadcastData) ...[
                  ..._section(
                    context,
                    'Upcoming',
                    Icons.event_outlined,
                    upcoming,
                    _BroadcastKind.upcoming,
                    'No upcoming broadcasts available.',
                  ),
                  ..._section(
                    context,
                    'Recent Broadcasts',
                    Icons.history,
                    repository.replays,
                    _BroadcastKind.replay,
                    'Completed DCGTV broadcasts will appear here.',
                  ),
                ],
              ],
              FilledButton.icon(
                onPressed: () => openInAppLink(context, _channelUrl),
                style: FilledButton.styleFrom(
                  backgroundColor: dcgRed,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.ondemand_video),
                label: const Text('Browse All Broadcasts'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeading({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Semantics(
          header: true,
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
        ),
      );
}

enum _BroadcastKind {
  live('LIVE', 'Watch Live', Icons.sensors),
  unverified('Live at last update', 'View Stream', Icons.history),
  upcoming('Upcoming', 'View Stream', Icons.event_outlined),
  replay('Replay', 'Watch Replay', Icons.replay);

  final String label;
  final String action;
  final IconData icon;

  const _BroadcastKind(this.label, this.action, this.icon);
}

class _BroadcastCard extends StatelessWidget {
  final DcgStream stream;
  final _BroadcastKind kind;
  final ValueChanged<Uri> onOpen;

  const _BroadcastCard({
    required this.stream,
    required this.kind,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isLive = kind == _BroadcastKind.live;
    final isReplay = kind == _BroadcastKind.replay;
    final date = stream.startDate;
    final url = stream.safeUrl;

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isLive
                ? dcgRed
                : isReplay
                    ? colors.secondaryContainer
                    : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            kind.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isLive
                  ? Colors.white
                  : isReplay
                      ? colors.onSecondaryContainer
                      : colors.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          stream.displayTitle,
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (date != null) ...[
          const SizedBox(height: 3),
          Text(
            localDateTime(context, date),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
        if (url != null) ...[
          const SizedBox(height: 5),
          Text.rich(
            TextSpan(
              children: [
                WidgetSpan(
                  child: Icon(kind.icon, size: 15, color: colors.primary),
                  alignment: PlaceholderAlignment.middle,
                ),
                TextSpan(text: ' ${kind.action}'),
              ],
            ),
            style: theme.textTheme.labelMedium?.copyWith(color: colors.primary),
          ),
        ],
      ],
    );

    final thumbnail = BroadcastThumbnail(url: stream.thumbnail);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isReplay ? 12 : 16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: url == null ? null : () => onOpen(url),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final textSize = MediaQuery.textScalerOf(context).scale(14);
              if (constraints.maxWidth < 280 || textSize > 21) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 160, child: thumbnail),
                    const SizedBox(height: 8),
                    details
                  ],
                );
              }
              return Row(
                children: [
                  SizedBox(width: isReplay ? 104 : 120, child: thumbnail),
                  const SizedBox(width: 12),
                  Expanded(child: details),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
