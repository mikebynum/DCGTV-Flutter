class DcgStream {
  final String id;
  final String title;
  final String status;
  final String thumbnail;
  final String url;
  final String? scheduledStart;

  const DcgStream({
    required this.id, required this.title, required this.status,
    required this.thumbnail, required this.url, this.scheduledStart,
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
  DateTime? get startDate => scheduledStart == null
      ? null : DateTime.tryParse(scheduledStart!);
  Uri? get safeUrl {
    final parsed = Uri.tryParse(url);
    return parsed != null && parsed.scheme == 'https' &&
        parsed.host.isNotEmpty && parsed.userInfo.isEmpty ? parsed : null;
  }
}

class StreamResponse {
  final String channel;
  final List<DcgStream> streams;
  final List<DcgStream> replays;
  const StreamResponse(this.channel, this.streams, this.replays);

  factory StreamResponse.fromJson(Map<String, dynamic> json) {
    List<DcgStream> parse(dynamic value) {
      if (value == null) return [];
      if (value is! List) throw const FormatException('Expected stream list');
      return value.map((item) =>
        DcgStream.fromJson(item as Map<String, dynamic>)).toList();
    }
    return StreamResponse(
      json['channel'] as String,
      parse(json['streams']),
      parse(json['replays']),
    );
  }

  Map<String, dynamic> toJson() => {
    'channel': channel,
    'streams': streams.map(_streamToJson).toList(),
    'replays': replays.map(_streamToJson).toList(),
  };

  static Map<String, dynamic> _streamToJson(DcgStream s) => {
    'id': s.id, 'title': s.title, 'status': s.status,
    'thumbnail': s.thumbnail, 'url': s.url,
    'scheduled_start': s.scheduledStart,
  };
}
