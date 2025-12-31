import '../domain/models/ward.dart';


abstract class WardRepository {
  Future<List<Ward>> fetchWards({required int hospitalCode});
}