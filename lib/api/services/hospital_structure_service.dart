import '../api_client.dart';

class HospitalStructureService {
  final ApiClient _c;
  HospitalStructureService(this._c);

  /// 병동(parts) 조회: /api/hospital/structure/part?hospital_code=1
  Future<List<Map<String, dynamic>>> fetchParts({required int hospitalCode}) async {
    final res = await _c.dio.get(
      '/api/hospital/structure/part',
      queryParameters: {'hospital_code': hospitalCode},
    );

    final body = res.data;
    if (body is! Map<String, dynamic>) {
      throw Exception('Invalid response');
    }
    if (body['code'] != 1) {
      throw Exception((body['message'] ?? '병동 조회 실패').toString());
    }

    final data = body['data'] as Map<String, dynamic>;
    final parts = (data['parts'] as List).cast<Map<String, dynamic>>();
    return parts;
  }
}
