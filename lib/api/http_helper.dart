import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ✅ 웹이면 http_helper_web_client.dart
// ✅ 태블릿/데스크탑(IO)이면 http_helper_io_client.dart
import 'http_helper_web_client.dart' if (dart.library.io) 'http_helper_io_client.dart';

class HttpHelper {
  static http.Client? _client;

  /// ✅ 앱 전체에서 동일 Client를 재사용해야 쿠키/세션이 유지됩니다.
  static http.Client get _c => _client ??= createHttpClient();

  static Map<String, String> _baseHeaders([Map<String, String>? headers]) {
    return <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (headers != null) ...headers,
    };
  }

  static Map<String, dynamic>? _tryDecodeMap(String s) {
    try {
      final v = jsonDecode(s);
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      return null;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _decodeMap(String s) {
    final decoded = jsonDecode(s);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw Exception('Invalid JSON format (not a Map)');
  }

  static void _throwIfHttpError(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }
  }

  static void _log(String method, Uri uri, {Object? reqBody, required http.Response res}) {
    debugPrint('[$method] ${uri.toString()} -> ${res.statusCode}');
    if (reqBody != null) debugPrint('REQ: ${jsonEncode(reqBody)}');
    debugPrint('RES: ${res.body}');
  }

  /// ✅ HTTP 에러(401/403/500 등)여도 JSON 메시지를 "그대로 받고" 싶을 때 사용
  /// - 예: SettingsDialog에서 401일 때 {"code":-1,"message":"로그인이 필요합니다."} 를 그대로 받기
  static Future<Map<String, dynamic>> sendJsonAllowError(
      String method,
      Uri uri, {
        Map<String, dynamic>? body,
        Map<String, String>? headers,
      }) async {
    final req = http.Request(method, uri);
    req.headers.addAll(_baseHeaders(headers));
    if (body != null) req.body = jsonEncode(body);

    final streamed = await _c.send(req); // ✅ _c 사용 (null 문제 방지 + 쿠키 유지)
    final res = await http.Response.fromStream(streamed);

    _log(method, uri, reqBody: body, res: res);

    final decoded = _tryDecodeMap(res.body);
    if (decoded != null) {
      decoded['httpStatus'] ??= res.statusCode;
      return decoded;
    }

    return <String, dynamic>{
      'code': -1,
      'message': 'Invalid JSON',
      'raw': res.body,
      'httpStatus': res.statusCode,
    };
  }

  /// ✅ GET (성공 시에만 통과)
  static Future<Map<String, dynamic>> getJson(
      Uri uri, {
        Map<String, String>? headers,
      }) async {
    final res = await _c.get(uri, headers: _baseHeaders(headers));

    _log('GET', uri, reqBody: null, res: res);
    _throwIfHttpError(res);

    return _decodeMap(res.body);
  }

  /// ✅ GET (401이어도 body를 받고 싶을 때)
  static Future<Map<String, dynamic>> getJsonAllowError(
      Uri uri, {
        Map<String, String>? headers,
      }) async {
    final res = await _c.get(uri, headers: _baseHeaders(headers));
    _log('GET', uri, reqBody: null, res: res);

    final decoded = _tryDecodeMap(res.body);
    if (decoded != null) {
      decoded['httpStatus'] ??= res.statusCode;
      return decoded;
    }

    return <String, dynamic>{
      'code': -1,
      'message': 'Invalid JSON',
      'raw': res.body,
      'httpStatus': res.statusCode,
    };
  }

  /// ✅ POST (성공 시에만 통과)
  static Future<Map<String, dynamic>> postJson(
      Uri uri,
      Map<String, dynamic> body, {
        Map<String, String>? headers,
      }) async {
    final res = await _c.post(
      uri,
      headers: _baseHeaders(headers),
      body: jsonEncode(body),
    );

    _log('POST', uri, reqBody: body, res: res);
    _throwIfHttpError(res);

    return _decodeMap(res.body);
  }

  /// ✅ PUT (성공 시에만 통과)
  static Future<Map<String, dynamic>> putJson(
      Uri uri,
      Map<String, dynamic> body, {
        Map<String, String>? headers,
      }) async {
    final res = await _c.put(
      uri,
      headers: _baseHeaders(headers),
      body: jsonEncode(body),
    );

    _log('PUT', uri, reqBody: body, res: res);
    _throwIfHttpError(res);

    return _decodeMap(res.body);
  }

  /// ✅ PUT/DELETE 등 공통 (성공 시에만 통과)
  static Future<Map<String, dynamic>> sendJson(
      String method,
      Uri uri, {
        Map<String, dynamic>? body,
        Map<String, String>? headers,
      }) async {
    final req = http.Request(method, uri);
    req.headers.addAll(_baseHeaders(headers));
    if (body != null) req.body = jsonEncode(body);

    final streamed = await _c.send(req);
    final res = await http.Response.fromStream(streamed);

    _log(method, uri, reqBody: body, res: res);
    _throwIfHttpError(res);

    return _decodeMap(res.body);
  }

  /// ✅ 앱 종료 시 정리(필수 아님)
  static void close() {
    _client?.close();
    _client = null;
  }
}
