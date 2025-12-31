import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/ward_select_providers.dart';
import '../dashboard/providers/ward_providers.dart';



class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final idCtrl = TextEditingController();
  final pwCtrl = TextEditingController();

  bool loading = false;
  bool authed = true; // 로그인 성공 여부(성공 시 병동 선택 화면으로 전환)

  @override
  void dispose() {
    idCtrl.dispose();
    pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _mockLogin() async {
    // TODO(백엔드 연동): 여기서 auth api 호출 -> 토큰 저장(SecureKV) 등으로 변경
    final id = idCtrl.text.trim();
    final pw = pwCtrl.text.trim();

    if (id.isEmpty || pw.isEmpty) {
      _snack('ID와 비밀번호를 입력해 주세요.');
      return;
    }

    setState(() => loading = true);
    await Future.delayed(const Duration(milliseconds: 450));
    setState(() {
      loading = false;
      authed = true;
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = _AuthCard(
      title: authed ? '병동 선택' : '로그인',
      subtitle: authed ? '대시보드로 이동할 병동을 선택해 주세요.' : '계정 정보를 입력해 주세요.',
      child: authed ? _WardButtons() : _LoginForm(onLogin: _mockLogin, loading: loading, idCtrl: idCtrl, pwCtrl: pwCtrl),
      footer: authed
          ? TextButton(
        onPressed: () {
          // 병동 선택 화면에서 다시 로그인 화면으로 돌아가기
          ref.read(selectedWardProvider.notifier).state = null;
          setState(() => authed = false);
        },
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
                // 왼쪽 타이틀 영역(스크린샷 느낌 유지)
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 24),
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
                  ),
                ),

                // 오른쪽 카드(로그인/병동선택)
                Expanded(flex: 2, child: card),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget footer;

  const _AuthCard({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.footer,
  });

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
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
          const SizedBox(height: 18),
          child,
          const SizedBox(height: 14),
          Center(child: footer),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  final Future<void> Function() onLogin;
  final bool loading;
  final TextEditingController idCtrl;
  final TextEditingController pwCtrl;

  const _LoginForm({
    required this.onLogin,
    required this.loading,
    required this.idCtrl,
    required this.pwCtrl,
  });

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String hint) {
      return InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF93C5FD))),
      );
    }

    final btnStyle = ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF65C466), // 스샷 느낌의 그린
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
        TextField(controller: idCtrl, decoration: deco('아이디를 입력'), textInputAction: TextInputAction.next),
        const SizedBox(height: 14),
        const Text('Password', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF111827))),
        const SizedBox(height: 8),
        TextField(controller: pwCtrl, obscureText: true, decoration: deco('비밀번호를 입력'), onSubmitted: (_) => onLogin()),
        const SizedBox(height: 18),
        ElevatedButton(
          style: btnStyle,
          onPressed: loading ? null : onLogin,
          child: loading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('로그인'),
        ),
      ],
    );
  }
}

class _WardButtons extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncWards = ref.watch(wardListProvider);

    final btnStyle = ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF65C466), // 로그인 버튼과 동일 톤
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
      elevation: 0,
    );

    return asyncWards.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('병동 목록을 불러오지 못했습니다.', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => ref.invalidate(wardListProvider),
            child: const Text('다시 시도'),
          ),
        ],
      ),
      data: (wards) {
        if (wards.isEmpty) {
          return const Text('등록된 병동이 없습니다.', style: TextStyle(fontWeight: FontWeight.w800));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final w in wards) ...[
              ElevatedButton(
                style: btnStyle,
                onPressed: () {
                  ref.read(selectedWardProvider.notifier).state = w;
                  context.go('/dashboard'); // 선택된 병동은 provider로 전달
                },
                child: Text(w.categoryName),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 2),
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
}
