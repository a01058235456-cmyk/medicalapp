import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../domain/models/ward.dart';
import 'ward_repository.dart';

class WardApiRepository implements WardRepository {
  final Dio _dio;
  WardApiRepository(ApiClient c) : _dio = c.dio;

  @override
  Future<List<Ward>> fetchWards({required int hospitalCode}) async {
    final res = await _dio.get(
      '/hospital/structure/part',
      queryParameters: {'hospital_code': hospitalCode},
    );

    final body = res.data;
    if (body is! Map<String, dynamic>) throw Exception('Invalid response');
    if (body['code'] != 1) throw Exception((body['message'] ?? '병동 조회 실패').toString());

    final data = body['data'] as Map<String, dynamic>;
    final parts = (data['parts'] as List).cast<Map<String, dynamic>>();

    return parts.map(Ward.fromJson).toList();
  }

  @override
  Future<Ward> createWard({
    required int hospitalCode,
    required String categoryName,
    int? sortOrder,
  }) => throw UnimplementedError();

  @override
  Future<Ward> updateWard({
    required int hospitalCode,
    required int hospitalStCode,
    required String categoryName,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteWard({
    required int hospitalCode,
    required int hospitalStCode,
  }) => throw UnimplementedError();
}
