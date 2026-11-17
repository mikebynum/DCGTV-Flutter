import 'package:flutter/material.dart';
import '../features/watch/watch_screen.dart';

const dcgRed = Color(0xFFC8102E);

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
        seedColor: dcgRed, brightness: Brightness.dark,
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

class _DcgTvShellState extends State<DcgTvShell> {
  int selected = 1;
  @override
  Widget build(BuildContext context) {
    const labels = ['Home', 'Watch', 'Schedule', 'Shows'];
    const icons = [
      Icons.home, Icons.live_tv, Icons.calendar_month, Icons.movie,
    ];
    return Scaffold(
      body: IndexedStack(index: selected, children: const [
        _PendingScreen(title: 'Home'),
        WatchScreen(),
        _PendingScreen(title: 'Schedule'),
        _PendingScreen(title: 'Shows'),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (index) => setState(() => selected = index),
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
