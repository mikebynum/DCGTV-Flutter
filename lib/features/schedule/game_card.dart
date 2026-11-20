import 'package:flutter/material.dart';

import '../../core/presentation.dart';
import '../../models/dcg_game.dart';

class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.game,
    this.showDate = false,
    this.matchedBroadcastUrl,
  });

  final DcgGame game;
  final bool showDate;
  final Uri? matchedBroadcastUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final external = game.externalStream;
    final dcgtv = game.dcgtvUrl ?? matchedBroadcastUrl;
    final details = game.detailsUrl;
    final location = game.location;
    final status = game.status;
    final start = game.start;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              [game.sport, game.level]
                  .where((part) => part.isNotEmpty)
                  .join(' · '),
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 4),
            Text(game.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _GameFact(
                  icon: Icons.schedule,
                  text: start == null
                      ? 'Time to be confirmed'
                      : showDate
                          ? localDateTime(context, start)
                          : localTime(context, start),
                ),
                if (location != null)
                  _GameFact(icon: Icons.place_outlined, text: location),
              ],
            ),
            if (status != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(status, style: theme.textTheme.labelLarge),
              ),
            if (dcgtv != null)
              FilledButton.icon(
                onPressed: () => openInAppLink(context, dcgtv),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Watch on DCGTV'),
              ),
            if (external != null) ...[
              OutlinedButton.icon(
                onPressed: () => openInAppLink(context, external.url),
                icon: const Icon(Icons.play_arrow),
                label: Text(external.provider == null
                    ? 'Watch external broadcast'
                    : 'Watch via ${external.provider}'),
              ),
              if (external.note != null)
                Text(external.note!, style: theme.textTheme.bodySmall),
            ],
            if (details != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => openInAppLink(context, details),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Game details on Bound'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GameFact extends StatelessWidget {
  const _GameFact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Icon(icon, size: 15),
          ),
          TextSpan(text: ' $text'),
        ]),
        style: Theme.of(context).textTheme.bodySmall,
      );
}
