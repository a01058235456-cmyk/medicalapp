import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_config.dart';
import '../../storage/secure_kv.dart';
import '../../api/api_client.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return const AppConfig(
    baseUrl: AppConfig.apiBaseUrl, // ✅ 3000 확정
    env: 'dev',
  );
});

final secureKVProvider = Provider<SecureKV>((ref) => MemorySecureKV());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    config: ref.watch(appConfigProvider),
    secure: ref.watch(secureKVProvider),
  );
});
