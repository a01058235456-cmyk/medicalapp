import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../domain/models/ward.dart';
import '../../../data/ward_repository.dart';
import '../../../data/mock/mock_ward_repository.dart';
import '../../../data/ward_api_repository.dart';
import '../../../app/providers/core_providers.dart';

/// 로그인 성공 시 hospital_code 저장
final hospitalCodeProvider = StateProvider<int?>((ref) => null);

final wardRepositoryProvider = Provider<WardRepository>((ref) {
  if (AppConfig.useMockBackend) return MockWardRepository();
  return WardApiRepository(ref.watch(apiClientProvider));
});

final wardListProvider = FutureProvider<List<Ward>>((ref) async {
  final hospitalCode = ref.watch(hospitalCodeProvider);
  if (hospitalCode == null) return [];
  return ref.watch(wardRepositoryProvider).fetchWards(hospitalCode: hospitalCode);
});

final selectedWardProvider = StateProvider<Ward?>((ref) => null);
