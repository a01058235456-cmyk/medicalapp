import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';

http.Client createHttpClient() {
  final c = BrowserClient()..withCredentials = true; // ✅ 쿠키 자동 포함(크롬)
  return c;
}
