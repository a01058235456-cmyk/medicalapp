class AppConfig {
  final String baseUrl;
  final String env;

  const AppConfig({required this.baseUrl, required this.env});
  // ✅ 지금은 true로 더미 동작
  static const bool useMockBackend = false;
    static const String apiBaseUrl = 'http://localhost:3000'; // 크롬,윈도우 용
  // static const String apiBaseUrl = 'http://10.0.2.2:3000'; //애뮬레이터 Test

  factory AppConfig.fromEnv() {
    const baseUrl = String.fromEnvironment('BASE_URL', defaultValue: 'http://10.0.2.2:8080');
    const env = String.fromEnvironment('ENV', defaultValue: 'dev');
    return const AppConfig(baseUrl: baseUrl, env: env);
  }
}