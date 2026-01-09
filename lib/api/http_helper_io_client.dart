import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// ✅ IO(안드로이드 태블릿/윈도우/맥):
/// dart:io HttpClient는 "같은 인스턴스"를 쓰는 동안
/// Set-Cookie 받은 세션 쿠키를 메모리에 저장하고, 다음 요청에 자동 전송합니다.
http.Client createHttpClient() {
  final io = HttpClient();

  // 로컬 개발 시 self-signed 인증서 쓰면 필요할 수 있음(HTTP면 상관없음)
  // io.badCertificateCallback = (X509Certificate cert, String host, int port) => true;

  io.autoUncompress = true;

  return IOClient(io);
}
