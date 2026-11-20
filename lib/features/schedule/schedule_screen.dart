import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/presentation.dart';
import '../../models/dcg_game.dart';
import '../../services/games_repository.dart';

final _fullSchedule =
    Uri.https('www.gobound.com', '/ia/schools/dallascentergrimes');

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.active, this.repository});

  final bool active;
  final GamesRepository? repository;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with WidgetsBindingObserver {
  late final _repository = widget.repository ?? GamesRepository();
  final _search = TextEditingController();
  var _sport = '';
  var _level = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) unawaited(_repository.refresh());
  }

  @override
  void didUpdateWidget(ScheduleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      unawaited(_repository.refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.active && state == AppLifecycleState.resumed) {
      unawaited(_repository.refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.repository == null) _repository.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() => _repository.refresh(force: true);

  Map<DateTime?, List<DcgGame>> _groupGames() {
    final today = DateUtils.dateOnly(DateTime.now());
    final query = _search.text
        .trim()
        .toLowerCase()
        .replaceAll('dallas center-grimes', 'dcg');
    final groups = <DateTime?, List<DcgGame>>{};
    for (final game in _repository.games) {
      final start = game.start;
      final day = start == null ? null : DateUtils.dateOnly(start.toLocal());
      if (day != null && day.isBefore(today)) continue;
      if (_sport.isNotEmpty && game.sport != _sport) continue;
      if (_level.isNotEmpty && game.level != _level) continue;
      if (!game.matchesSearch(query)) continue;
      (groups[day] ??= []).add(game);
    }
    return groups;
  }

  void _clearFilters() {
    setState(() {
      _search.clear();
      _sport = '';
      _level = '';
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _repository,
        builder: (context, child) {
          final games = _repository.games;
          final sports = games.map((game) => game.sport).toSet().toList()
            ..sort();
          final levels = games.map((game) => game.level).toSet().toList()
            ..sort();
          final groups = _groupGames();
          final hasFilters =
              _search.text.isNotEmpty || _sport.isNotEmpty || _level.isNotEmpty;
          final updated = _repository.lastUpdated;
          final isLoading = _repository.isLoading;
          final localizations = MaterialLocalizations.of(context);

          return Scaffold(
            body: SafeArea(
              bottom: false,
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Semantics(
                      header: true,
                      child: Image.asset(
                        'assets/schedule/DCGTVScheduleHeader.png',
                        semanticLabel: 'DCGTV Schedule',
                        fit: BoxFit.fitWidth,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isLoading)
                      const LinearProgressIndicator(
                          semanticsLabel: 'Updating schedule'),
                    if (_repository.showingSaved ||
                        _repository.refreshFailed) ...[
                      Text(
                        _repository.refreshFailed
                            ? updated != null
                                ? 'Couldn’t refresh. Showing the saved schedule.'
                                : 'Couldn’t load the schedule. Check your connection and retry.'
                            : 'Showing the saved schedule.',
                      ),
                      if (!isLoading)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ),
                    ],
                    if (updated != null)
                      Text(
                        'Last updated ${localDateTime(context, updated)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (games.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          labelText: 'Search games',
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () => setState(_search.clear),
                                  icon: const Icon(Icons.clear),
                                ),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _ScheduleFilter(
                            allLabel: 'All sports',
                            options: sports,
                            selected: _sport,
                            onSelected: (sport) =>
                                setState(() => _sport = sport),
                          ),
                          if (levels.length > 1 || _level.isNotEmpty)
                            _ScheduleFilter(
                              allLabel: 'All levels',
                              options: levels,
                              selected: _level,
                              onSelected: (level) =>
                                  setState(() => _level = level),
                            ),
                          if (hasFilters)
                            TextButton(
                              onPressed: _clearFilters,
                              child: const Text('Clear filters'),
                            ),
                        ],
                      ),
                    ],
                    if (updated != null && groups.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          hasFilters
                              ? 'No games match these filters.'
                              : 'No upcoming games.',
                        ),
                      ),
                    for (final MapEntry(key: day, value: games)
                        in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 14, bottom: 8),
                        child: Semantics(
                          header: true,
                          child: Text(
                            day == null
                                ? 'Date to be confirmed'
                                : localizations.formatFullDate(day),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                      for (final game in games)
                        _GameCard(key: ValueKey(game.id), game: game),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => openInAppLink(context, _fullSchedule),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('View Full Schedule on Bound'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}

class _ScheduleFilter extends StatelessWidget {
  const _ScheduleFilter({
    required this.allLabel,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String allLabel;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: allLabel,
        initialValue: selected,
        onSelected: onSelected,
        itemBuilder: (context) => [
          PopupMenuItem(value: '', child: Text(allLabel)),
          for (final value in options)
            PopupMenuItem(value: value, child: Text(value)),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(selected.isEmpty ? allLabel : selected),
              const Icon(Icons.arrow_drop_down, size: 18),
            ],
          ),
        ),
      );
}

class _GameCard extends StatelessWidget {
  const _GameCard({super.key, required this.game});

  final DcgGame game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final external = game.externalStream;
    final dcgtv = game.dcgtvUrl;
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
