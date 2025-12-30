import '../api_client.dart';

class AuthApi {
  final ApiClient _client;
  AuthApi(this._client);

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _client.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return Map<String, dynamic>.from(res.data);
  }

  Future<void> logout() async {
    await _client.dio.post('/auth/logout');
  }

  Future<void> deleteMe() async {
    await _client.dio.delete('/users/me');
  }
}
