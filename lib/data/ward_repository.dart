import '../domain/models/ward.dart';


abstract class WardRepository {
  Future<List<Ward>> fetchWards({required int hospitalCode});
  Future<Ward> createWard({
    required int hospitalCode,
    required String categoryName,
    int? sortOrder,
  });

  // ✅ 추가: 병동 이름 수정
  Future<Ward> updateWard({
    required int hospitalCode,
    required int hospitalStCode,
    required String categoryName,
  });

  // ✅ 추가: 병동 삭제
  Future<void> deleteWard({
    required int hospitalCode,
    required int hospitalStCode,
  });
}

