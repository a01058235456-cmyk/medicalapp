import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../urlConfig.dart'; // 경로 맞춰서 수정하세요.

class AuthApi {
  AuthApi();

  /// ✅ baseUrl은 urlConfig.dart의 serverUrl을 그대로 사용
  String get _baseUrl => Urlconfig.serverUrl;

  /// 명세: POST /api/auth/login
  Future<Map<String, dynamic>> login({
    required String hospitalId,
    required String hospitalPassword,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/auth/login');

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'hospital_id': hospitalId,
        'hospital_password': hospitalPassword,
      }),
    );

    debugPrint('[LOGIN] status=${res.statusCode}');
    debugPrint('[LOGIN] body=${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('로그인 실패(HTTP ${res.statusCode})');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      throw Exception('서버 응답 형식이 올바르지 않습니다.');
    }

    return Map<String, dynamic>.from(decoded);
  }
}
