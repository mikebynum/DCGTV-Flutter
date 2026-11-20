import 'dart:convert';
import 'package:http/http.dart' as http;

class DcgApiClient {
  DcgApiClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static final base = Uri.parse('https://dcgboosterclub.com/wp-json/dcg/v1/');

  Future<Map<String, dynamic>> getObject(String endpoint) async {
    final response = await _client.get(base.resolve(endpoint))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('DCGTV API returned HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object');
    }
    return decoded;
  }

  void close() => _client.close();
}
