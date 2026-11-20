import 'dart:async';

import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';
import '../features/schedule/schedule_screen.dart';
import '../features/shows/shows_screen.dart';
import '../features/watch/watch_screen.dart';
import '../services/games_repository.dart';
import '../services/results_repository.dart';
import '../services/shows_repository.dart';
import '../services/streams_repository.dart';
import 'dcg_theme.dart';

class DcgTvApp extends StatelessWidget {
  const DcgTvApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'DCGTV',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: dcgTheme(Brightness.light),
        darkTheme: dcgTheme(Brightness.dark),
        home: const DcgTvShell(),
      );
}

class DcgTvShell extends StatefulWidget {
  const DcgTvShell({super.key});
  @override
  State<DcgTvShell> createState() => _DcgTvShellState();
}

class _DcgTvShellState extends State<DcgTvShell> with WidgetsBindingObserver {
  final _streams = StreamsRepository();
  final _games = GamesRepository();
  final _results = ResultsRepository();
  final _shows = ShowsRepository();
  var _selected = 0;
  Timer? _streamRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_streams.initialize());
    _refreshSelectedTab();
    _startStreamRefreshTimer();
  }

  void _startStreamRefreshTimer() {
    _streamRefreshTimer?.cancel();
    // The repository checks LIVE expiry each tick and throttles network calls.
    _streamRefreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_streams.refresh()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _streamRefreshTimer?.cancel();
      return;
    }
    unawaited(_streams.refresh());
    _refreshSelectedTab();
    _startStreamRefreshTimer();
  }

  void _selectTab(int index) {
    if (_selected == index) return;
    setState(() => _selected = index);
    _refreshSelectedTab();
  }

  void _refreshSelectedTab() {
    if (_selected == 0 || _selected == 2) unawaited(_games.refresh());
    if (_selected == 0) unawaited(_results.refresh());
    if (_selected == 3) unawaited(_shows.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _streamRefreshTimer?.cancel();
    _streams.dispose();
    _games.dispose();
    _results.dispose();
    _shows.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['Home', 'Watch', 'Schedule', 'Shows'];
    const icons = [
      Icons.home,
      Icons.live_tv,
      Icons.calendar_month,
      Icons.movie,
    ];
    return Scaffold(
      body: IndexedStack(index: _selected, children: [
        HomeScreen(
          streams: _streams,
          games: _games,
          results: _results,
          onShowWatch: () => _selectTab(1),
          onShowSchedule: () => _selectTab(2),
        ),
        WatchScreen(repository: _streams),
        ScheduleScreen(repository: _games),
        ShowsScreen(repository: _shows),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selected,
        onDestinationSelected: _selectTab,
        destinations: [
          for (var i = 0; i < labels.length; i++)
            NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
        ],
      ),
    );
  }
}
