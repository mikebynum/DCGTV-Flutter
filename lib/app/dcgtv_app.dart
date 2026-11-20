import 'dart:async';

import 'package:flutter/material.dart';

import '../core/presentation.dart';
import '../features/home/home_screen.dart';
import '../features/schedule/schedule_screen.dart';
import '../features/watch/watch_screen.dart';
import '../services/games_repository.dart';
import '../services/streams_repository.dart';

class DcgTvApp extends StatelessWidget {
  const DcgTvApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'DCGTV',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: dcgRed),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: dcgRed,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
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
  var _selected = 0;
  Timer? _streamRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_streams.initialize());
    unawaited(_games.refresh());
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
    if (_selected == 0 || _selected == 2) unawaited(_games.refresh());
    _startStreamRefreshTimer();
  }

  void _selectTab(int index) {
    if (_selected == index) return;
    setState(() => _selected = index);
    if (index == 0 || index == 2) unawaited(_games.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _streamRefreshTimer?.cancel();
    _streams.dispose();
    _games.dispose();
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
          onShowWatch: () => _selectTab(1),
          onShowSchedule: () => _selectTab(2),
        ),
        WatchScreen(repository: _streams),
        ScheduleScreen(repository: _games),
        const _PendingScreen(title: 'Shows'),
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

class _PendingScreen extends StatelessWidget {
  final String title;
  const _PendingScreen({required this.title});
  @override
  Widget build(BuildContext context) => Center(
        child: Text('$title — coming in a later milestone'),
      );
}
