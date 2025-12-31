import '../../domain/models/ward.dart';
import '../ward_repository.dart';

class MockWardRepository implements WardRepository {
  @override
  Future<List<Ward>> fetchWards({required int hospitalCode}) async {
    await Future.delayed(const Duration(milliseconds: 350));

    // hospitalCode에 따라 다르게 주고 싶으면 여기서 분기 가능



    return const [
      Ward(hospitalStCode: 1, categoryName: '1 병동', sortOrder: 1),
      Ward(hospitalStCode: 2, categoryName: '2 병동', sortOrder: 2),
      Ward(hospitalStCode: 3, categoryName: 'VIP 실', sortOrder: 3),
      // 필요하면 더 추가
      // Ward(hospitalStCode: 4, categoryName: '중환자실', sortOrder: 4),
    ];
  }
}