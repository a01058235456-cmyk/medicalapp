import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'providers/ward_select_providers.dart' as ws;




/// Login API

class LoginResult {
  final bool ok;
  final int? hospitalCode;
  final String message;

  const LoginResult({
    required this.ok,
    required this.message,
    this.hospitalCode,
  });
}

class _LoginApi {
  static String get baseUrl {
    // 필요 시 Android Emulator:
    // return kIsWeb ? 'http://localhost:3000' : 'http://10.0.2.2:3000';
    return kIsWeb ? 'http://localhost:3000' : 'http://localhost:3000';
  }

  static Future<LoginResult> login({
    required String hospitalId,
    required String hospitalPassword,
  }) async {
    final uri = Uri.parse('$baseUrl/api/auth/login');

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'hospital_id': hospitalId,
        'hospital_password': hospitalPassword,
      }),
    );

    debugPrint('[LOGIN] status=${res.statusCode}');
    debugPrint('[LOGIN] body=${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      return LoginResult(ok: false, message: '로그인 실패(HTTP ${res.statusCode})');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      return const LoginResult(ok: false, message: '서버 응답(JSON) 파싱 실패');
    }

    if (decoded is! Map) {
      return const LoginResult(ok: false, message: '서버 응답 형식이 올바르지 않습니다.');
    }

    final ok = decoded['code'] == 1;

    // 실패/성공 공통으로 message 안전 추출
    String message = '로그인 실패';
    final dynamic dataAny = decoded['data'];
    if (dataAny is Map && dataAny['message'] != null) {
      message = dataAny['message'].toString();
    } else if (decoded['message'] != null) {
      message = decoded['message'].toString();
    }

    if (!ok) {
      return LoginResult(ok: false, message: message);
    }

    // 성공 케이스 hospital_code 안전 파싱
    if (dataAny is! Map) {
      return const LoginResult(ok: false, message: '로그인 성공 응답(data)이 비어있습니다.');
    }

    final hospitalCode = int.tryParse(dataAny['hospital_code']?.toString() ?? '');
    if (hospitalCode == null) {
      return const LoginResult(ok: false, message: '병원 코드(hospital_code)를 읽지 못했습니다.');
    }

    return LoginResult(ok: true, message: '로그인 성공', hospitalCode: hospitalCode);
  }
}






/// Screen

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final idCtrl = TextEditingController();
  final pwCtrl = TextEditingController();

  bool loading = false;
  bool authed = true;

  @override
  void dispose() {
    idCtrl.dispose();
    pwCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
      final result = await _LoginApi.login(hospitalId: id, hospitalPassword: pw);
      if (!mounted) return;

      if (!result.ok) {
        setState(() {
          loading = false;
          authed = false;
        });
        _snack(result.message);
        return;
      }

      // 로그인 성공 → hospital_code 저장 → 병동 목록 트리거
      ref.read(ws.hospitalCodeProvider.notifier).state = result.hospitalCode;

      // 병동 목록 새로고침(선택)
      ref.invalidate(ws.wardListProvider);

      setState(() {
        loading = false;
        authed = true;
      });
    } catch (e) {
      debugPrint('[LOGIN] error=$e');
      if (!mounted) return;

      setState(() {
        loading = false;
        authed = false;
      });
      _snack('요청 실패: $e');
    }
  }

  void _backToLogin() {
    // ws/dp 모두 초기화해서 꼬임 방지
    ref.read(ws.selectedWardProvider.notifier).state = null;
    ref.read(ws.hospitalCodeProvider.notifier).state = null;

    ref.invalidate(ws.wardListProvider);

    setState(() => authed = false);
  }

  @override
  Widget build(BuildContext context) {
    final card = _AuthCard(
      title: authed ? '병동 선택' : '로그인',
      subtitle: authed ? '대시보드로 이동할 병동을 선택해 주세요.' : '계정 정보를 입력해 주세요.',
      child: authed
          ? const _WardButtons()
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

/// =======================================================
/// 모든 위젯 Stateful로 통일
/// =======================================================
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
          Text(widget.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
          const SizedBox(height: 6),
          Text(widget.subtitle,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
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

/// =======================================================
/// Ward Select (ConsumerStatefulWidget로 변경)
/// =======================================================
class _WardButtons extends ConsumerStatefulWidget {
  const _WardButtons({super.key});

  @override
  ConsumerState<_WardButtons> createState() => _WardButtonsState();
}

class _WardButtonsState extends ConsumerState<_WardButtons> {
  @override
  Widget build(BuildContext context) {
    final asyncWards = ref.watch(ws.wardListProvider);

    final btnStyle = ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF65C466),
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
      elevation: 0,
    );

    final addBtnStyle = OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF65C466),
      side: const BorderSide(color: Color(0xFF65C466), width: 1.2),
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
    );

    return asyncWards.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '병동 목록을 불러오지 못했습니다.',
            style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => ref.invalidate(ws.wardListProvider),
            child: const Text('다시 시도'),
          ),
        ],
      ),
      data: (wards) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wards.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('등록된 병동이 없습니다.', style: TextStyle(fontWeight: FontWeight.w800)),
              )
            else
              for (final w in wards) ...[
                ElevatedButton(
                  style: btnStyle,
                  onPressed: () {
                    ref.read(ws.selectedWardProvider.notifier).state = w;
                    GoRouter.of(context).go('/dashboard');
                  },
                  child: Text(w.categoryName),
                ),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 6),
            OutlinedButton.icon(
              style: addBtnStyle,
              icon: const Icon(Icons.add),
              label: const Text('병동 추가'),
              onPressed: () async {
                final name = await _showAddWardDialog(context);
                if (name == null) return;

                try {
                  final hospitalCode = ref.read(ws.hospitalCodeProvider);
                  if (hospitalCode == null) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('병원 코드가 없습니다. 다시 로그인해 주세요.')),
                    );
                    return;
                  }

                  await ref.read(ws.wardRepositoryProvider).createWard(
                    hospitalCode: hospitalCode,
                    categoryName: name,
                  );

                  ref.invalidate(ws.wardListProvider);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('병동이 추가되었습니다: $name')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('병동 추가 실패: $e')),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 10),
            const Text(
              '※ 병동 목록은 (추후) DB/백엔드에서 받아 자동 생성됩니다.',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }



  //병동 추가 라인
  Future<String?> _showAddWardDialog(BuildContext context) async {
    final ctrl = TextEditingController();

    const green = Color(0xFF16A34A);
    const border = Color(0xFFE5E7EB);
    const text = Color(0xFF111827);
    const subText = Color(0xFF6B7280);

    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: border),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
        actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        title: const Text(
          '병동 추가',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: text),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          cursorColor: green,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: text),
          decoration: InputDecoration(
            hintText: '예) 3병동, 중환자실, VIP실',
            hintStyle: const TextStyle(color: subText, fontWeight: FontWeight.w600),
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: green, width: 1.6),
            ),
          ),
          onSubmitted: (_) {
            final v = ctrl.text.trim();
            if (v.isEmpty) return;
            Navigator.pop(ctx, v);
          },
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: subText,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: green,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isEmpty) return;
              Navigator.pop(ctx, v);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }
}
