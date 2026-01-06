import '../api_client.dart';

class HospitalStructureService {
  final ApiClient _c;
  HospitalStructureService(this._c);

  Future<List<Map<String, dynamic>>> fetchParts({required int hospitalCode}) async {
    final res = await _c.dio.get(
      '/api/hospital/structure/part',
      queryParameters: {'hospital_code': hospitalCode},
    );

    final body = res.data;
    if (body is! Map) throw Exception('Invalid response: not a map');
    if (body['code'] != 1) throw Exception((body['message'] ?? '병동 조회 실패').toString());

    final data = body['data'];
    if (data is! Map) throw Exception('Invalid response: data not a map');

    final rawParts = data['parts'];
    if (rawParts is! List) return const [];

    // ✅ 지금 서버 응답 keys: hospital_code, category_name, sort_order
    return rawParts
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
