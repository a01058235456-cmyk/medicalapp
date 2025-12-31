import '../api_client.dart';

class AuthApi {
  final ApiClient _client;
  AuthApi(this._client);

  /// 명세: POST /api/auth/login
  Future<Map<String, dynamic>> login({
    required String hospitalId,
    required String hospitalPassword,
  }) async {
    final res = await _client.dio.post(
      '/api/auth/login',
      data: {
        'hospital_id': hospitalId,
        'hospital_password': hospitalPassword,
      },
    );
    return Map<String, dynamic>.from(res.data);
  }
}


// Future<void> logout() async {
//   await _client.dio.post('/auth/logout');
// }
//
// Future<void> deleteMe() async {
//   await _client.dio.delete('/users/me');
// }