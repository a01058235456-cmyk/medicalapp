import '../domain/models/ward.dart';
import 'ward_repository.dart';
import '../api/services/hospital_structure_service.dart';

class DioWardRepository implements WardRepository {
  final HospitalStructureService _svc;
  DioWardRepository(this._svc);

  @override
  Future<List<Ward>> fetchWards({required int hospitalCode}) async {
    final parts = await _svc.fetchParts(hospitalCode: hospitalCode);

    final wards = parts.map((p) {
      // 서버 응답: { hospital_code, category_name, sort_order }

      final stCode = int.tryParse(p['hospital_code'].toString()) ?? 0;
      final name = (p['category_name'] ?? '').toString();
      final sort = int.tryParse(p['sort_order'].toString()) ?? 0;

      return Ward(
        hospitalStCode: stCode,
        categoryName: name,
        sortOrder: sort,
      );
    }).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return wards;
  }

  @override
  Future<Ward> createWard({
    required int hospitalCode,
    required String categoryName,
  }) {
    // 백엔드에 “단건 추가 API”가 아직 없으면 일단 막아두기(컴파일은 됨)
    throw UnsupportedError('백엔드에 병동 단건 생성 API가 필요합니다.');
  }

  @override
  Future<Ward> updateWard({
    required int hospitalCode,
    required int hospitalStCode,
    required String categoryName,
  }) {
    throw UnsupportedError('백엔드에 병동 수정 API가 필요합니다.');
  }

  @override
  Future<void> deleteWard({
    required int hospitalCode,
    required int hospitalStCode,
  }) {
    throw UnsupportedError('백엔드에 병동 삭제 API가 필요합니다.');
  }
}
