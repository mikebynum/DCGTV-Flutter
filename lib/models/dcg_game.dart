import '../core/https_link.dart';

class DcgGame {
  const DcgGame._({
    required this.id,
    required this.title,
    required this.sport,
    required this.level,
    required this.start,
    this.location,
    this.status,
    this.detailsUrl,
    this.dcgtvUrl,
    this.externalStream,
  });

  final String id;
  final String title;
  final String sport;
  final String level;
  final DateTime? start;
  final String? location;
  final String? status;
  final Uri? detailsUrl;
  final Uri? dcgtvUrl;
  final ExternalBroadcast? externalStream;

  factory DcgGame.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] as String).trim();
    final sport = (json['sport'] as String).trim();
    final level = (json['level'] as String).trim();
    final prefix = '$sport:';
    final suffix = '($level)';
    var event = title;
    if (event.toLowerCase().startsWith(prefix.toLowerCase())) {
      event = event.substring(prefix.length).trim();
    }
    if (event.toLowerCase().endsWith(suffix.toLowerCase())) {
      event = event.substring(0, event.length - suffix.length).trimRight();
    }
    final location = _optionalText(json['location']);
    const homePrefix = 'Dallas Center-Grimes High School ';
    final status = _optionalText(json['status']);
    final start = _optionalText(json['start']);
    final dcgtvStream = json['dcgtv_stream'];
    return DcgGame._(
      id: json['id'] as String,
      title: event.isEmpty
          ? title
          : event.replaceAll(
              RegExp('Dallas Center-Grimes', caseSensitive: false), 'DCG'),
      sport: sport,
      level: level,
      start: start == null ? null : DateTime.tryParse(start),
      location: location != null &&
              location.toLowerCase().startsWith(homePrefix.toLowerCase())
          ? location.substring(homePrefix.length).trim()
          : location,
      status: status?.toUpperCase() == 'CONFIRMED' ? null : status,
      detailsUrl: safeHttpsUrl(_optionalText(json['url'])),
      dcgtvUrl: dcgtvStream is Map<String, dynamic>
          ? safeHttpsUrl(_optionalText(dcgtvStream['url']))
          : null,
      externalStream: ExternalBroadcast.fromJson(json['external_stream']),
    );
  }

  bool matchesSearch(String query) =>
      '$title $sport $level ${location ?? ''}'.toLowerCase().contains(query);
}

class ExternalBroadcast {
  const ExternalBroadcast(this.url, this.provider, this.note);

  final Uri url;
  final String? provider;
  final String? note;

  static ExternalBroadcast? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final url = safeHttpsUrl(_optionalText(json['url']));
    if (url == null) return null;
    return ExternalBroadcast(
      url,
      _optionalText(json['provider']),
      _optionalText(json['note']),
    );
  }
}

String? _optionalText(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;
