import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class HttpHelper {
  static Future<Map<String, dynamic>> getJson(Uri uri) async {
    final res = await http.get(uri, headers: {'Content-Type': 'application/json'});

    debugPrint('[HTTP GET] ${uri.toString()}');
    debugPrint('[HTTP GET] status=${res.statusCode}');
    debugPrint('[HTTP GET] body=${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid JSON format');
    }
    return decoded;
  }

  static Future<Map<String, dynamic>> postJson(Uri uri, Map<String, dynamic> body) async {
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    debugPrint('[HTTP POST] ${uri.toString()}');
    debugPrint('[HTTP POST] status=${res.statusCode}');
    debugPrint('[HTTP POST] body=${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid JSON format');
    }
    return decoded;
  }
}
