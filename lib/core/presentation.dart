import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const dcgRed = Color(0xFFC8102E);

String localTime(BuildContext context, DateTime date) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(date.toLocal()),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

String localDateTime(BuildContext context, DateTime date) {
  final day = MaterialLocalizations.of(context).formatFullDate(date.toLocal());
  return '$day • ${localTime(context, date)}';
}

Future<void> openInAppLink(BuildContext context, Uri url) async {
  try {
    if (await launchUrl(url, mode: LaunchMode.inAppBrowserView)) return;
  } on Exception catch (error) {
    debugPrint('Could not open link: $error');
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Unable to open link')),
  );
}
