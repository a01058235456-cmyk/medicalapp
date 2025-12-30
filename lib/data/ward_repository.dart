import '../domain/models/ward.dart';

abstract class WardRepository {
  /// (나중에) DB/백엔드에서 병동 목록 가져오기
  Future<List<Ward>> fetchWards();
}
