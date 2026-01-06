import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/ward.dart';
import '../../../data/ward_repository.dart';
import '../../../data/mock/mock_ward_repository.dart';

import '../../../api/services/hospital_structure_service.dart';
import '../../../data/dio_ward_repository.dart';

// ✅ AppConfig 제거: mock 사용 여부는 여기서 고정(필요하면 true로 바꿔서 테스트)
const bool useMockBackend = true;

final hospitalCodeProvider = StateProvider<int?>((ref) => null);

final wardRepositoryProvider = Provider<WardRepository>((ref) {
  if (useMockBackend) return MockWardRepository();

  // ✅ apiClientProvider는 "Urlconfig.serverUrl" 기반으로 만들어져 있어야 합니다.
  // (apiClientProvider 쪽 파일에서 baseUrl을 Urlconfig.serverUrl로 고정하세요)
  final client = ref.watch(apiClientProvider);
  final svc = HospitalStructureService(client);
  return DioWardRepository(svc);
});

final wardListProvider = FutureProvider<List<Ward>>((ref) async {
  final hospitalCode = ref.watch(hospitalCodeProvider);
  if (hospitalCode == null) return [];

  final wards = await ref.watch(wardRepositoryProvider).fetchWards(
    hospitalCode: hospitalCode,
  );

  return wards;
});

final selectedWardProvider = StateProvider<Ward?>((ref) => null);
