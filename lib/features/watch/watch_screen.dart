import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/dcgtv_app.dart';
import '../../models/dcg_stream.dart';
import '../../services/streams_repository.dart';

class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key});
  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> with WidgetsBindingObserver {
  late final StreamsRepository repository;
  Timer? refreshTimer;
  Timer? freshnessTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    repository = StreamsRepository();
    repository.addListener(_rebuild);
    repository.initialize();
    _startTimers();
  }

  void _rebuild() { if (mounted) setState(() {}); }

  void _startTimers() {
    refreshTimer?.cancel();
    freshnessTimer?.cancel();
    refreshTimer = Timer.periodic(const Duration(seconds: 60),
        (_) => repository.refresh());
    freshnessTimer = Timer.periodic(const Duration(seconds: 5),
        (_) => repository.expireStatusIfNeeded());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      repository.expireStatusIfNeeded();
      repository.refresh();
      _startTimers();
    } else {
      refreshTimer?.cancel();
      freshnessTimer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    refreshTimer?.cancel();
    freshnessTimer?.cancel();
    repository.removeListener(_rebuild);
    repository.dispose();
    super.dispose();
  }

  Future<void> _open(Uri? url) async {
    if (url == null) return;
    if (!await launchUrl(url, mode: LaunchMode.inAppBrowserView)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open video')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('DCGTV • Watch')),
    body: RefreshIndicator(
      onRefresh: () => repository.refresh(force: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: dcgRed, borderRadius: BorderRadius.circular(16)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WATCH LIVE & ON DEMAND',
                  style: TextStyle(color: Colors.white, fontSize: 21,
                    fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text('Mustang pride. Wherever you are.',
                  style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (repository.isLoading) const LinearProgressIndicator(),
          if (repository.errorMessage != null)
            Text(repository.lastUpdated == null
                ? 'Broadcasts could not be loaded. Pull to retry.'
                : 'Could not refresh. Showing saved information; live status is unverified.'),
          if (!repository.isStatusCurrent && repository.lastUpdated != null &&
              repository.errorMessage == null)
            const Text('Saved broadcasts. Live status is unverified.'),
          if (repository.lastUpdated != null)
            Text('Last updated: ${repository.lastUpdated!.toLocal()}',
                style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Text('Live & Upcoming', style: Theme.of(context).textTheme.titleLarge),
          if (repository.streams.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No live or upcoming broadcasts available.')),
          ...repository.streams.map((s) => _StreamTile(
            stream: s, isStatusCurrent: repository.isStatusCurrent,
            onTap: () => _open(s.safeUrl),
          )),
          const SizedBox(height: 16),
          Text('Replays', style: Theme.of(context).textTheme.titleLarge),
          if (repository.replays.isEmpty)
            const Text('No replays available.'),
          ...repository.replays.map((s) => _StreamTile(
            stream: s, isStatusCurrent: repository.isStatusCurrent,
            onTap: () => _open(s.safeUrl),
          )),
          const SizedBox(height: 16),
          Card(child: ListTile(
            title: const Text('DCGTV livestreams presented by Charter Bank'),
            subtitle: const Text('Official livestream sponsor'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _open(Uri.parse('https://www.charterbanker.com/')),
          )),
        ],
      ),
    ),
  );
}

class _StreamTile extends StatelessWidget {
  final DcgStream stream;
  final bool isStatusCurrent;
  final VoidCallback onTap;
  const _StreamTile({required this.stream, required this.isStatusCurrent,
    required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: stream.safeUrl == null ? null : onTap,
      leading: SizedBox(width: 96, height: 60,
        child: stream.thumbnail.startsWith('https://')
          ? Image.network(stream.thumbnail, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.live_tv))
          : const Icon(Icons.live_tv)),
      title: Text(stream.title, maxLines: 2,
        overflow: TextOverflow.ellipsis),
      subtitle: Text([
        if (stream.isLive) isStatusCurrent ? 'LIVE NOW' : 'LIVE AT LAST UPDATE'
        else if (stream.isUpcoming) 'Upcoming' else 'Replay',
        if (stream.startDate != null) stream.startDate!.toLocal().toString(),
      ].join(' • ')),
      trailing: const Icon(Icons.play_circle_outline, color: dcgRed),
    ),
  );
}
