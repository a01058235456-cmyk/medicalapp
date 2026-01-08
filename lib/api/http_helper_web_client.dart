import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';

http.Client createHttpClient() {
  final c = BrowserClient();
  c.withCredentials = true; // ✅ 세션 쿠키(connect.sid) 자동 포함
  return c;
}
