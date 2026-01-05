import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/ward_repository.dart';
import '../../../data/mock/mock_ward_repository.dart';
import '../../../domain/models/ward.dart';

final wardRepositoryProvider = Provider<WardRepository>((ref) {
  return MockWardRepository();
});

final wardListProvider = FutureProvider<List<Ward>>((ref) async {
  const hospitalCode = 1; // TODO: 로그인 응답으로 교체
  final repo = ref.watch(wardRepositoryProvider);
  return repo.fetchWards(hospitalCode: hospitalCode);
});

final selectedWardProvider = StateProvider<Ward?>((ref) => null);
