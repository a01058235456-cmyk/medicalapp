import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/mock/mock_ward_repository.dart';
import '../../../data/ward_repository.dart';
import '../../../domain/models/ward.dart';


/// 나중에 백엔드 붙이면 MockWardRepository -> ApiWardRepository로 교체만 하면 됩니다.
final wardRepositoryProvider = Provider<WardRepository>((ref) {
  return MockWardRepository();
});

// /// 로그인 성공 후, 병동 버튼을 만들기 위한 목록
// final wardListProvider = FutureProvider<List<Ward>>((ref) async {
//   final repo = ref.watch(wardRepositoryProvider);
//   return repo.fetchWards();
// });

/// 사용자가 선택한 병동(대시보드에서 읽음)
// final selectedWardProvider = StateProvider<Ward?>((ref) => null);
/// 더미: 나중에 DB/백엔드로 교체할 자리
///
///
final wardListProvider = FutureProvider<List<Ward>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 250));
  return const [
    Ward(hospitalStCode: 1, categoryName: 'A병동', sortOrder: 1),
    Ward(hospitalStCode: 2, categoryName: 'B병동', sortOrder: 2),
    Ward(hospitalStCode: 3, categoryName: 'C병동', sortOrder: 3)
  ];
});