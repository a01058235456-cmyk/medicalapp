import 'package:http/http.dart' as http;

class CookieClient extends http.BaseClient {
  final http.Client _inner;
  final Map<String, String> _jar = {}; // name -> value

  CookieClient([http.Client? inner]) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_jar.isNotEmpty) {
      request.headers['Cookie'] = _jar.entries.map((e) => '${e.key}=${e.value}').join('; ');
    }

    final res = await _inner.send(request);

    final setCookie = res.headers['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      _storeSetCookie(setCookie);
    }

    return res;
  }

  void _storeSetCookie(String raw) {
    final first = raw.split(';').first; // "connect.sid=...."
    final idx = first.indexOf('=');
    if (idx <= 0) return;
    final name = first.substring(0, idx).trim();
    final value = first.substring(idx + 1).trim();
    if (name.isEmpty) return;
    _jar[name] = value;
  }

  @override
  void close() => _inner.close();
}

http.Client createHttpClient() => CookieClient();
