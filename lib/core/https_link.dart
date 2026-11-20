Uri? safeHttpsUrl(String? url) {
  if (url == null) return null;
  final parsed = Uri.tryParse(url);
  return parsed != null &&
          parsed.scheme == 'https' &&
          parsed.host.isNotEmpty &&
          parsed.userInfo.isEmpty
      ? parsed
      : null;
}
