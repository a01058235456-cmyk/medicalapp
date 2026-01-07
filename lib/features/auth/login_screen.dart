import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:medicalapp/storage_keys.dart';
import 'package:medicalapp/urlConfig.dart';

/// =======================
/// Models (간단 모델)
/// =======================
class WardItem {
  final int hospitalStCode;
  final String categoryName;
  final int sortOrder;

  const WardItem({
    required this.hospitalStCode,
    required this.categoryName,
    required this.sortOrder,
  });

  factory WardItem.fromJson(Map<String, dynamic> j) {
    return WardItem(
      hospitalStCode: int.tryParse(j['hospital_st_code']?.toString() ?? '') ?? 0,
      categoryName: (j['category_name'] ?? '').toString(),
      sortOrder: int.tryParse(j['sort_order']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'hospital_st_code': hospitalStCode,
    'category_name': categoryName,
    'sort_order': sortOrder,
  };
}

/// =======================
/// Screen (스토리지 + API / provider 없음)
/// =======================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _storage = FlutterSecureStorage();


  // storage keys
  static const _kHospitalCode = 'hospital_code';
  static const _kSelectedWardJson = 'selected_ward_json';

  late final String _front_url;

  final idCtrl = TextEditingController();
  final pwCtrl = TextEditingController();

  bool loading = false; // 로그인 로딩
  bool wardsLoading = false; // 병동 로딩
  bool authed = false;

  int? hospitalCode;
  List<WardItem> wards = [];

  bool _autoRouted = false; // wards 비었을 때 자동 라우팅 1회만

  @override
  void initState() {
    super.initState();
    _front_url = Urlconfig.serverUrl.toString();
    loadData();
  }

  @override
  void dispose() {
    idCtrl.dispose();
    pwCtrl.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    await _bootstrapFromStorage();
  }

  Future<void> _bootstrapFromStorage() async {
    try {
      final codeStr = await _storage.read(key: _kHospitalCode);
      final code = int.tryParse(codeStr ?? '');
      hospitalCode = code;

      // 선택 병동이 있으면 바로 대시보드로
      final wardJson = await _storage.read(key: _kSelectedWardJson);
      if (wardJson != null && wardJson.isNotEmpty) {try {
        final m = jsonDecode(wardJson);
        if (m is Map) {
          final w = WardItem.fromJson(Map<String, dynamic>.from(m));
          await _storage.write(key: StorageKeys.selectedWardStCode, value: w.hospitalStCode.toString());
          await _storage.write(key: StorageKeys.selectedWardName, value: w.categoryName);
        }
      } catch (_) {}

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go('/dashboard');
      });
      return;
      }

      if (hospitalCode != null) {
        setState(() => authed = true);
        await getData(); // 병동 목록 로드
      } else {
        setState(() => authed = false);
      }
    } catch (e) {
      debugPrint('[BOOTSTRAP] error=$e');
      if (!mounted) return;
      setState(() => authed = false);
    }
  }

  Future<void> getData() async {
    // ✅ 병동 목록 조회 (/api/hospital/structure/part)
    if (hospitalCode == null) return;

    try {
      setState(() {
        wardsLoading = true;
        _autoRouted = false;
      });

      final uri = Uri.parse('$_front_url/api/hospital/structure/part?hospital_code=$hospitalCode');
      final res = await http.get(uri);

      debugPrint('[WARDS] status=${res.statusCode}');
      debugPrint('[WARDS] body=${res.body}');

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('병동 조회 실패(HTTP ${res.statusCode})');
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map) throw Exception('병동 조회 응답 형식 오류');

      final ok = decoded['code'] == 1;
      if (!ok) throw Exception((decoded['message'] ?? '병동 조회 실패').toString());

      final data = decoded['data'];
      if (data is! Map) throw Exception('병동 조회 data가 비었습니다.');

      final parts = data['parts'];
      final List<WardItem> next = [];
      if (parts is List) {
        for (final e in parts) {
          if (e is Map<String, dynamic>) {
            next.add(WardItem.fromJson(e));
          } else if (e is Map) {
            next.add(WardItem.fromJson(Map<String, dynamic>.from(e)));
          }
        }
      }

      // sort_order 정렬(선택)
      next.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      if (!mounted) return;
      setState(() {
        wards = next;
        wardsLoading = false;
      });

      // ✅ 병동이 없으면 예외 UI 없이 대시보드로 바로 이동
      if (wards.isEmpty && !_autoRouted) {
        _autoRouted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.go('/dashboard');
        });
      }
    } catch (e) {
      debugPrint('[WARDS] error=$e');
      if (!mounted) return;
      setState(() {
        wards = [];
        wardsLoading = false;
      });

      // 에러는 최소 알림만 (원치 않으면 주석)
      _snack('병동 조회 실패: $e');
    }
  }

  Future<void> _login() async {
    final id = idCtrl.text.trim();
    final pw = pwCtrl.text.trim();

    if (id.isEmpty || pw.isEmpty) {
      _snack('ID와 비밀번호를 입력해 주세요.');
      return;
    }

    setState(() => loading = true);

    try {
      final uri = Uri.parse('$_front_url/api/auth/login');

      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'hospital_id': id,
          'hospital_password': pw,
        }),
      );

      debugPrint('[LOGIN] status=${res.statusCode}');
      debugPrint('[LOGIN] body=${res.body}');

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('로그인 실패(HTTP ${res.statusCode})');
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map) throw Exception('로그인 응답 형식 오류');

      final ok = decoded['code'] == 1;
      if (!ok) {
        final msg = (decoded['message'] ?? '로그인 실패').toString();
        throw Exception(msg);
      }

      final data = decoded['data'];
      if (data is! Map) throw Exception('로그인 응답 data가 비었습니다.');

      final code = int.tryParse(data['hospital_code']?.toString() ?? '');
      if (code == null) throw Exception('병원 코드(hospital_code)를 읽지 못했습니다.');

      // ✅ storage 저장
      await _storage.write(key: _kHospitalCode, value: code.toString());

      if (!mounted) return;
      setState(() {
        hospitalCode = code;
        authed = true;
        loading = false;
      });

      // ✅ 병동 목록 로드
      await getData();
    } catch (e) {
      debugPrint('[LOGIN] error=$e');
      if (!mounted) return;
      setState(() {
        loading = false;
        authed = false;
      });
      _snack('로그인 실패: $e');
    }
  }

  Future<void> _selectWard(WardItem w) async {
    // ✅ 선택 병동 저장 후 대시보드로
    await _storage.write(key: _kSelectedWardJson, value: jsonEncode(w.toJson()));

    // ✅ 대시보드가 읽는 키들로도 저장
    await _storage.write(key: StorageKeys.selectedWardStCode, value: w.hospitalStCode.toString());
    await _storage.write(key: StorageKeys.selectedWardName, value: w.categoryName);

    if (!mounted) return;
    context.go('/dashboard');
  }

  Future<void> _backToLogin() async {
    // storage 초기화
    await _storage.delete(key: StorageKeys.selectedWardStCode);
    await _storage.delete(key: StorageKeys.selectedWardName);

    if (!mounted) return;
    setState(() {
      authed = false;
      hospitalCode = null;
      wards = [];
      _autoRouted = false;
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final card = _AuthCard(
      title: authed ? '병동 선택' : '로그인',
      subtitle: authed ? '대시보드로 이동할 병동을 선택해 주세요.' : '계정 정보를 입력해 주세요.',
      child: authed
          ? _WardButtons(
        wards: wards,
        loading: wardsLoading,
        onRetry: getData,
        onSelect: _selectWard,
      )
          : _LoginForm(
        onLogin: _login,
        loading: loading,
        idCtrl: idCtrl,
        pwCtrl: pwCtrl,
      ),
      footer: authed
          ? TextButton(
        onPressed: _backToLogin,
        child: const Text('다른 계정으로 로그인'),
      )
          : const Text(
        '문제가 있으면 관리자에게 문의해 주세요.',
        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Expanded(flex: 3, child: _LeftIntro()),
                const SizedBox(width: 24),
                Expanded(flex: 2, child: card),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// =======================
/// UI Widgets (전부 Stateful)
/// =======================

class _LeftIntro extends StatefulWidget {
  const _LeftIntro({super.key});

  @override
  State<_LeftIntro> createState() => _LeftIntroState();
}

class _LeftIntroState extends State<_LeftIntro> {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            '병동 모니터링 시스템',
            style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
          ),
          SizedBox(height: 16),
          Text(
            '로그인 후 전체 환자 현황 및 건강 상태를 관리합니다.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _AuthCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget footer;

  const _AuthCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.footer,
  });

  @override
  State<_AuthCard> createState() => _AuthCardState();
}

class _AuthCardState extends State<_AuthCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 6),
          Text(
            widget.subtitle,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 18),
          widget.child,
          const SizedBox(height: 14),
          Center(child: widget.footer),
        ],
      ),
    );
  }
}

class _LoginForm extends StatefulWidget {
  final Future<void> Function() onLogin;
  final bool loading;
  final TextEditingController idCtrl;
  final TextEditingController pwCtrl;

  const _LoginForm({
    super.key,
    required this.onLogin,
    required this.loading,
    required this.idCtrl,
    required this.pwCtrl,
  });

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  InputDecoration _deco(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF3F4F6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF93C5FD)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final btnStyle = ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF65C466),
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
      elevation: 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ID', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF111827))),
        const SizedBox(height: 8),
        TextField(
          controller: widget.idCtrl,
          decoration: _deco('아이디를 입력'),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        const Text('Password', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF111827))),
        const SizedBox(height: 8),
        TextField(
          controller: widget.pwCtrl,
          obscureText: true,
          decoration: _deco('비밀번호를 입력'),
          onSubmitted: (_) => widget.onLogin(),
        ),
        const SizedBox(height: 18),
        ElevatedButton(
          style: btnStyle,
          onPressed: widget.loading ? null : widget.onLogin,
          child: widget.loading
              ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
              : const Text('로그인'),
        ),
      ],
    );
  }
}

class _WardButtons extends StatefulWidget {
  final List<WardItem> wards;
  final bool loading;
  final Future<void> Function() onRetry;
  final Future<void> Function(WardItem w) onSelect;

  const _WardButtons({
    super.key,
    required this.wards,
    required this.loading,
    required this.onRetry,
    required this.onSelect,
  });

  @override
  State<_WardButtons> createState() => _WardButtonsState();
}

class _WardButtonsState extends State<_WardButtons> {
  @override
  Widget build(BuildContext context) {
    final btnStyle = ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF65C466),
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
      elevation: 0,
    );

    if (widget.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // ✅ 병동 없을 때 UI 없이 넘어가는 건 상위(getData)에서 처리됨
    // 여기서는 그냥 빈 Column 반환
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final w in widget.wards) ...[
          ElevatedButton(
            style: btnStyle,
            onPressed: () => widget.onSelect(w),
            child: Text(w.categoryName),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton(
          onPressed: widget.onRetry,
          child: const Text('새로고침'),
        ),
      ],
    );
  }
}
