import '../../domain/models/ward.dart';
import '../ward_repository.dart';

class MockWardRepository implements WardRepository {
  @override
  Future<List<Ward>> fetchWards() async {
    // 실제 DB/백엔드 연동 시 여기 대신 API 호출로 교체됩니다.
    await Future.delayed(const Duration(milliseconds: 350));

    return const [
      Ward(id: 'ward-1', name: '1병동'),
      Ward(id: 'ward-2', name: '2병동'),
      Ward(id: 'ward-3', name: '3병동'),
      Ward(id: 'ward-icu', name: '중환자실'),
    ];
  }
}
