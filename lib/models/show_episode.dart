import '../core/https_link.dart';

enum ShowSeries {
  fullGallop(
    'full_gallop',
    'Mustang Full Gallop',
    'Football conversations and interviews',
  ),
  seniorSpotlight(
    'senior_spotlight',
    'Senior Spotlight',
    'Celebrating DCG senior athletes',
  );

  const ShowSeries(this.feedKey, this.title, this.description);

  final String feedKey;
  final String title;
  final String description;
}

class ShowEpisode {
  const ShowEpisode._({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.url,
    required this.publishedAt,
  });

  final String id;
  final String title;
  final String thumbnail;
  final Uri url;
  final DateTime? publishedAt;

  static ShowEpisode? tryParse(Object? data) {
    if (data is! Map<String, dynamic>) return null;
    final id = data['id'];
    final title = data['title'];
    final url = _youtubeVideoUrl(data['url']);
    if (id is! String ||
        id.trim().isEmpty ||
        title is! String ||
        title.trim().isEmpty ||
        url == null) {
      return null;
    }
    final publishedAt = data['published_at'];
    final thumbnail = data['thumbnail'];
    return ShowEpisode._(
      id: id,
      title: title.trim(),
      thumbnail:
          thumbnail is String ? safeHttpsUrl(thumbnail)?.toString() ?? '' : '',
      url: url,
      publishedAt:
          publishedAt is String ? DateTime.tryParse(publishedAt) : null,
    );
  }
}

final _videoId = RegExp(r'^[A-Za-z0-9_-]{11}$');

Uri? _youtubeVideoUrl(Object? value) {
  if (value is! String) return null;
  final url = safeHttpsUrl(value);
  if (url == null) return null;
  final id = switch ((url.host, url.pathSegments)) {
    ('youtu.be', [final id]) => id,
    ('youtube.com' || 'www.youtube.com' || 'm.youtube.com', ['watch']) =>
      url.queryParameters['v'],
    (
      'youtube.com' || 'www.youtube.com' || 'm.youtube.com',
      ['shorts' || 'live', final id]
    ) =>
      id,
    _ => null,
  };
  return id != null && _videoId.hasMatch(id) ? url : null;
}
