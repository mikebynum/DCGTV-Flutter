import '../core/https_link.dart';

class DcgResult {
  const DcgResult._({
    required this.title,
    required this.sport,
    required this.level,
    required this.date,
    required this.dcgScore,
    required this.opponentScore,
    required this.detailsUrl,
  });

  final String title;
  final String sport;
  final String level;
  final DateTime? date;
  final int dcgScore;
  final int opponentScore;
  final Uri? detailsUrl;

  String get outcome {
    if (dcgScore == opponentScore) return 'Tie';
    return dcgScore > opponentScore ? 'Win' : 'Loss';
  }

  static DcgResult? tryParse(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final status = value['status'];
    final title = value['title'];
    final sport = value['sport'];
    final level = value['level'];
    final dcgScore = value['dcg_score'];
    final opponentScore = value['opponent_score'];
    if (status is! String ||
        status.trim().toLowerCase() != 'final' ||
        title is! String ||
        sport is! String ||
        level is! String ||
        dcgScore is! int ||
        opponentScore is! int) {
      return null;
    }

    final prefix = '$sport:';
    final suffix = '($level)';
    var matchup = title.trim();
    if (matchup.startsWith(prefix)) {
      matchup = matchup.substring(prefix.length).trim();
    }
    if (matchup.endsWith(suffix)) {
      matchup =
          matchup.substring(0, matchup.length - suffix.length).trimRight();
    }
    final start = value['start'];
    final url = value['url'];
    return DcgResult._(
      title: matchup.replaceAll('Dallas Center-Grimes', 'DCG'),
      sport: sport,
      level: level,
      date: start is String ? DateTime.tryParse(start) : null,
      dcgScore: dcgScore,
      opponentScore: opponentScore,
      detailsUrl: url is String ? safeHttpsUrl(url) : null,
    );
  }
}
