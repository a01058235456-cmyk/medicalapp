import '../../domain/models/ward.dart';
import '../ward_repository.dart';

class MockWardRepository implements WardRepository {
  final Map<int, List<Ward>> _store = {};

  List<Ward> _seed(int hospitalCode) {
    return [
      const Ward(hospitalStCode: 1, categoryName: '1 병동', sortOrder: 1),
      const Ward(hospitalStCode: 2, categoryName: '2 병동', sortOrder: 2),
      const Ward(hospitalStCode: 3, categoryName: 'VIP 실', sortOrder: 3),
    ];
  }

  List<Ward> _ensure(int hospitalCode) {
    return _store.putIfAbsent(hospitalCode, () => _seed(hospitalCode));
  }

  int _nextCode(List<Ward> list) {
    var mx = 0;
    for (final w in list) {
      if (w.hospitalStCode > mx) mx = w.hospitalStCode;
    }
    return mx + 1;
  }

  int _nextSort(List<Ward> list) {
    var mx = 0;
    for (final w in list) {
      if (w.sortOrder > mx) mx = w.sortOrder;
    }
    return mx + 1;
  }

  @override
  Future<List<Ward>> fetchWards({required int hospitalCode}) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final list = _ensure(hospitalCode);
    final sorted = [...list]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return sorted;
  }

  @override
  Future<Ward> createWard({
    required int hospitalCode,
    required String categoryName,
    int? sortOrder,
  }) async {
    await Future.delayed(const Duration(milliseconds: 180));
    final list = _ensure(hospitalCode);

    final name = categoryName.trim();
    if (name.isEmpty) throw ArgumentError('병동 이름이 비어있습니다.');

    final exists = list.any((w) => w.categoryName.trim() == name);
    if (exists) throw StateError('이미 존재하는 병동 이름입니다.');

    final created = Ward(
      hospitalStCode: _nextCode(list),
      categoryName: name,
      sortOrder: sortOrder ?? _nextSort(list),
    );
    list.add(created);
    return created;
  }

  @override
  Future<Ward> updateWard({
    required int hospitalCode,
    required int hospitalStCode,
    required String categoryName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 180));
    final list = _ensure(hospitalCode);

    final name = categoryName.trim();
    if (name.isEmpty) throw ArgumentError('병동 이름이 비어있습니다.');

    final idx = list.indexWhere((w) => w.hospitalStCode == hospitalStCode);
    if (idx < 0) throw StateError('수정할 병동을 찾지 못했습니다.');

    final exists = list.any((w) => w.hospitalStCode != hospitalStCode && w.categoryName.trim() == name);
    if (exists) throw StateError('이미 존재하는 병동 이름입니다.');

    final cur = list[idx];
    final next = Ward(
      hospitalStCode: cur.hospitalStCode,
      categoryName: name,
      sortOrder: cur.sortOrder,
    );

    list[idx] = next;
    return next;
  }

  @override
  Future<void> deleteWard({
    required int hospitalCode,
    required int hospitalStCode,
  }) async {
    await Future.delayed(const Duration(milliseconds: 160));
    final list = _ensure(hospitalCode);
    list.removeWhere((w) => w.hospitalStCode == hospitalStCode);
  }
}
