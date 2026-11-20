import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/home/home_screen.dart';
import '../features/schedule/schedule_screen.dart';
import '../features/shows/shows_screen.dart';
import '../features/watch/watch_screen.dart';
import '../services/games_repository.dart';
import '../services/results_repository.dart';
import '../services/shows_repository.dart';
import '../services/streams_repository.dart';
import 'dcg_theme.dart';
import 'floating_material_tab_bar.dart';
import 'glass_tab_bar.dart';

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
  var _useGlassTabBar = false;
  Timer? _streamRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_streams.initialize());
    _refreshSelectedTab();
    _startStreamRefreshTimer();
    unawaited(_loadTabBar());
  }

  Future<void> _loadTabBar() async {
    if (await GlassTabBar.isSupported() && mounted) {
      setState(() => _useGlassTabBar = true);
    }
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
    const destinations = [
      NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
      NavigationDestination(
          icon: Icon(Icons.ondemand_video_rounded), label: 'Watch'),
      NavigationDestination(
          icon: Icon(Icons.calendar_month_rounded), label: 'Schedule'),
      NavigationDestination(
          icon: Icon(Icons.local_movies_rounded), label: 'Shows'),
    ];
    final tabs = IndexedStack(index: _selected, children: [
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
    ]);
    final useAndroidBar =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final useFloatingBar = _useGlassTabBar || useAndroidBar;
    final showFloatingBar =
        useFloatingBar && MediaQuery.viewInsetsOf(context).bottom == 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Builder(builder: (context) {
          final media = MediaQuery.of(context);
          final barBottom = useAndroidBar
              ? media.padding.bottom + 8
              : (media.padding.bottom - 6).clamp(8.0, double.infinity);
          final barHeight = useAndroidBar
              ? FloatingMaterialTabBar.heightFor(media.textScaler)
              : GlassTabBar.height;
          final bottomPadding = barBottom + barHeight;
          return Stack(
            fit: StackFit.expand,
            children: [
              MediaQuery(
                data: showFloatingBar
                    ? media.copyWith(
                        padding: media.padding.copyWith(bottom: bottomPadding))
                    : media,
                child: tabs,
              ),
              if (showFloatingBar)
                Positioned(
                  left: media.padding.left + 16,
                  right: media.padding.right + 16,
                  bottom: barBottom,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 540),
                      child: useAndroidBar
                          ? FloatingMaterialTabBar(
                              destinations: destinations,
                              selectedIndex: _selected,
                              onSelected: _selectTab,
                              height: barHeight,
                            )
                          : GlassTabBar(
                              selectedIndex: _selected,
                              onSelected: _selectTab,
                            ),
                    ),
                  ),
                ),
            ],
          );
        }),
        bottomNavigationBar: useFloatingBar
            ? null
            : NavigationBar(
                selectedIndex: _selected,
                onDestinationSelected: _selectTab,
                destinations: destinations,
              ),
      ),
    );
  }
}
