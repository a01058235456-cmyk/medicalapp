import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../domain/models/ward.dart';
import '../../../data/ward_repository.dart';
import '../../../data/mock/mock_ward_repository.dart';
import '../../../app/providers/core_providers.dart';

import '../../../api/services/hospital_structure_service.dart';
import '../../../data/dio_ward_repository.dart';

final hospitalCodeProvider = StateProvider<int?>((ref) => null);

final wardRepositoryProvider = Provider<WardRepository>((ref) {
  if (AppConfig.useMockBackend) return MockWardRepository();

  final client = ref.watch(apiClientProvider); // ✅ 여기 “apiClientProvider”
  final svc = HospitalStructureService(client);
  return DioWardRepository(svc);
});

final wardListProvider = FutureProvider<List<Ward>>((ref) async {
  final hospitalCode = ref.watch(hospitalCodeProvider);

  if (hospitalCode == null) return [];

  final wards = await ref.watch(wardRepositoryProvider).fetchWards(hospitalCode: hospitalCode);


  return wards;
});

final selectedWardProvider = StateProvider<Ward?>((ref) => null);
