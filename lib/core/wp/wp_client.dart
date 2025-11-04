import 'dart:convert';

import 'package:http/http.dart' as http;

class WpPage {
  WpPage({required this.items, required this.totalPages});

  final List<Map<String, dynamic>> items;
  final int totalPages;
}

class WpClient {
  WpClient({http.Client? httpClient}) : _client = httpClient ?? http.Client();

  final http.Client _client;

  Future<WpPage> fetchPage(
    String baseUrl, {
    required int page,
    int perPage = 10,
    bool embed = true,
    Map<String, String>? extraParams,
  }) async {
    final hasQuery = baseUrl.contains('?');
    final params = <String, String>{
      if (embed) '_embed': '1',
      'status': 'publish',
      'per_page': '$perPage',
      'page': '$page',
      ...?extraParams,
    };

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final url = hasQuery ? '$baseUrl&$query' : '$baseUrl?$query';

    final res = await _client.get(Uri.parse(url));

    final headers = res.headers;
    final totalPagesStr =
        headers['x-wp-totalpages'] ??
        headers['X-WP-TotalPages'] ??
        headers['x-wp-total-pages'];
    final totalPages = int.tryParse(totalPagesStr ?? '') ?? 1;

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final list = body is List ? body : <dynamic>[];
      final items = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      return WpPage(items: items, totalPages: totalPages);
    }

    if (res.statusCode == 400 || res.statusCode == 404) {
      return WpPage(items: const [], totalPages: totalPages);
    }

    throw Exception('HTTP ${res.statusCode}');
  }
}
