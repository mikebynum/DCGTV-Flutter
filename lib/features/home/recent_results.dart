import 'package:flutter/material.dart';

import '../../core/presentation.dart';
import '../../models/dcg_result.dart';
import '../../services/results_repository.dart';

class RecentResults extends StatelessWidget {
  const RecentResults({super.key, required this.repository});

  final ResultsRepository repository;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Recent Results',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 8),
          if (repository.results.isEmpty)
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(repository.isLoading
                    ? 'Loading results…'
                    : repository.refreshFailed
                        ? 'Scores are temporarily unavailable.'
                        : 'No verified game scores have been posted yet.'),
              ),
            ),
          for (final result in repository.results.take(2))
            _ResultCard(result: result),
          if (repository.refreshFailed && repository.results.isNotEmpty)
            const Text('Showing saved results.'),
        ],
      );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final DcgResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = result.date;
    final url = result.detailsUrl;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${result.sport} · ${result.level}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(result.title, style: theme.textTheme.titleMedium),
            Semantics(
              excludeSemantics: true,
              label:
                  'Final. DCG ${result.dcgScore}, opponent ${result.opponentScore}. ${result.outcome}.',
              child: Text(
                'DCG ${result.dcgScore}–${result.opponentScore} · ${result.outcome}',
                style: theme.textTheme.titleSmall,
              ),
            ),
            if (date != null)
              Text(
                MaterialLocalizations.of(context)
                    .formatShortDate(date.toLocal()),
                style: theme.textTheme.bodySmall,
              ),
            if (url != null)
              TextButton.icon(
                onPressed: () => openInAppLink(context, url),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Game details on Bound'),
              ),
          ],
        ),
      ),
    );
  }
}
