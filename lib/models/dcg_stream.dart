import '../core/https_link.dart';

class DcgStream {
  final String id;
  final String title;
  final String status;
  final String thumbnail;
  final String url;
  final String? scheduledStart;

  const DcgStream({
    required this.id,
    required this.title,
    required this.status,
    required this.thumbnail,
    required this.url,
    this.scheduledStart,
  });

  factory DcgStream.fromJson(Map<String, dynamic> json) => DcgStream(
        id: json['id'] as String,
        title: json['title'] as String,
        status: json['status'] as String,
        thumbnail: json['thumbnail'] as String,
        url: json['url'] as String,
        scheduledStart: json['scheduled_start'] as String?,
      );

  bool get isLive => status.toLowerCase() == 'live';
  bool get isUpcoming => status.toLowerCase() == 'upcoming';
  DateTime? get startDate =>
      scheduledStart == null ? null : DateTime.tryParse(scheduledStart!);

  // The CMS sometimes embeds a date and time in the title. Keep matchup and
  // tournament details and show the feed timestamp in its own line.
  static final _titleDate = RegExp(
    r'\s+\d{1,2}[-/]\d{1,2}[-/]\d{2,4}'
    r'(?:\s*@\s*\d{1,2}(?::\d{2})?(?:\s*[ap]m)?)?(?=\s*(?:\(|$))',
    caseSensitive: false,
  );

  String get displayTitle {
    if (startDate == null) return title;
    final trimmed = title.replaceFirst(_titleDate, '').trim();
    return trimmed.isEmpty ? title : trimmed;
  }

  Uri? get safeUrl => safeHttpsUrl(url);
}

class StreamResponse {
  final String channel;
  final List<DcgStream> streams;
  final List<DcgStream> replays;
  final DateTime? updatedAt;
  final bool? stale;
  const StreamResponse(
    this.channel,
    this.streams,
    this.replays, {
    this.updatedAt,
    this.stale,
  });

  factory StreamResponse.fromJson(Map<String, dynamic> json) {
    List<DcgStream> parse(dynamic value) {
      if (value == null) return [];
      if (value is! List) throw const FormatException('Expected stream list');
      return value
          .map((item) => DcgStream.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    final timestamp = json['updated_at'];
    final updated = timestamp is String ? DateTime.tryParse(timestamp) : null;
    final stale = json['stale'];
    return StreamResponse(
      json['channel'] as String,
      parse(json['streams']),
      parse(json['replays']),
      updatedAt: updated?.isUtc == true ? updated : null,
      stale: stale is bool ? stale : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'channel': channel,
        'updated_at': updatedAt?.toIso8601String(),
        'stale': stale,
        'streams': streams.map(_streamToJson).toList(),
        'replays': replays.map(_streamToJson).toList(),
      };

  static Map<String, dynamic> _streamToJson(DcgStream s) => {
        'id': s.id,
        'title': s.title,
        'status': s.status,
        'thumbnail': s.thumbnail,
        'url': s.url,
        'scheduled_start': s.scheduledStart,
      };
}
