import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// 조건부 import (웹에서만 BrowserClient 사용)
import 'http_helper_web_client.dart'
if (dart.library.io) 'http_helper_io_client.dart';

class HttpHelper {
  static final http.Client _client = createHttpClient();

  static Future<Map<String, dynamic>> getJson(Uri uri) async {
    final res = await _client.get(uri, headers: _baseHeaders());

    debugPrint('[GET] $uri -> ${res.statusCode}');
    debugPrint('RES: ${res.body}');

    _throwIfBad(res);

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) throw Exception('Invalid JSON');
    return decoded;
  }

  static Future<Map<String, dynamic>> sendJson(
      String method,
      Uri uri, {
        Map<String, dynamic>? body,
      }) async {
    final req = http.Request(method, uri);
    req.headers.addAll(_baseHeaders());
    if (body != null) req.body = jsonEncode(body);

    final streamed = await _client.send(req);
    final res = await http.Response.fromStream(streamed);

    debugPrint('[$method] $uri -> ${res.statusCode}');
    debugPrint('REQ: ${req.body}');
    debugPrint('RES: ${res.body}');

    _throwIfBad(res);

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) throw Exception('Invalid JSON');
    return decoded;
  }

  static Map<String, String> _baseHeaders() => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static void _throwIfBad(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    // 서버가 {"message": "..."} 내려주는 케이스면 보여주기
    try {
      final j = jsonDecode(res.body);
      if (j is Map && j['message'] != null) {
        throw Exception('HTTP ${res.statusCode} / ${j['message']}');
      }
    } catch (_) {}

    throw Exception('HTTP ${res.statusCode}');
  }
}
