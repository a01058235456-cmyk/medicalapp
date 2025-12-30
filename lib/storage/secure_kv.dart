import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';



/// 앱 전역에서 쓰는 "보안 Key-Value" 래퍼
/// - 모바일/데스크탑: flutter_secure_storage 사용
/// - 웹(Chrome): flutter_secure_storage가 동작 제약이 있어, 메모리 폴백(임시) 제공
abstract class SecureKV {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

/// 웹/테스트용 간단 메모리 구현(새로고침 시 초기화)
class MemorySecureKV implements SecureKV {
  final Map<String, String> _m = {};

  @override
  Future<void> write(String key, String value) async => _m[key] = value;

  @override
  Future<String?> read(String key) async => _m[key];

  @override
  Future<void> delete(String key) async => _m.remove(key);

  @override
  Future<void> deleteAll() async => _m.clear();
}

/// 실제 저장소 구현
class FlutterSecureKV implements SecureKV {
  final FlutterSecureStorage _storage;

  FlutterSecureKV({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

/// 플랫폼에 맞는 기본 SecureKV를 만들어주는 헬퍼
SecureKV createSecureKV() {
  if (kIsWeb) return MemorySecureKV(); // ✅ 웹에서는 임시 폴백
  return FlutterSecureKV();
}
