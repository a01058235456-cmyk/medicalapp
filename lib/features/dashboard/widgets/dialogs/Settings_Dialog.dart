import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/providers/ward_select_providers.dart' as wards;

enum SettingsSection {
  accountInfo,   // 회원정보
  password,      // 비밀번호 변경
  withdraw,      // 회원 탈퇴
  mySettings,    // 내 설정
  systemInfo,    // 시스템 정보(앱 버전 등)
  wardManage,    // ✅ 병동 관리
}

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  SettingsSection _section = SettingsSection.accountInfo;

  Future<void> _logout(BuildContext context) async {
    // TODO(백엔드 연결 시):
    // 1) 토큰 삭제(SecureStorage/SharedPreferences)
    // 2) 전역 상태(Provider) 초기화
    // 3) 로그인 화면으로 이동

    if (!context.mounted) return;

    // ✅ 예시: 선택 병동 초기화 (프로젝트 구조에 맞게 통일된 provider로 바꾸세요)
    // ref.read(selectedWardProvider.notifier).state = null;

    // 설정창 닫기
    Navigator.pop(context);

    // ✅ 로그인 화면으로 이동
    GoRouter.of(context).go('/login');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('로그아웃 처리 로직을 연결하세요.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        width: 1120,
        height: 720,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 20,
              offset: Offset(0, 10),
            )
          ],
        ),
        child: Column(
          children: [
            // 상단 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 10, 12),
              child: Row(
                children: [
                  const Text('설정', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: Row(
                children: [
                  // 좌측 메뉴
                  Container(
                    width: 300,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      children: [
                        const _MenuTitle('회원 관리'),
                        _MenuItem(
                          title: '회원정보',
                          icon: Icons.badge_outlined,
                          selected: _section == SettingsSection.accountInfo,
                          onTap: () => setState(() => _section = SettingsSection.accountInfo),
                        ),
                        _MenuItem(
                          title: '비밀번호 변경',
                          icon: Icons.lock_outline,
                          selected: _section == SettingsSection.password,
                          onTap: () => setState(() => _section = SettingsSection.password),
                        ),
                        _MenuItem(
                          title: '회원 탈퇴',
                          icon: Icons.delete_outline,
                          danger: true,
                          selected: _section == SettingsSection.withdraw,
                          onTap: () => setState(() => _section = SettingsSection.withdraw),
                        ),

                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 10),

                        // ✅ 병동 관리 섹션 추가
                        const _MenuTitle('병동 관리'),
                        _MenuItem(
                          title: '병동 관리',
                          icon: Icons.apartment_outlined,
                          selected: _section == SettingsSection.wardManage,
                          onTap: () => setState(() => _section = SettingsSection.wardManage),
                        ),

                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 10),

                        const _MenuTitle('내 설정'),
                        _MenuItem(
                          title: '내 설정',
                          icon: Icons.tune,
                          selected: _section == SettingsSection.mySettings,
                          onTap: () => setState(() => _section = SettingsSection.mySettings),
                        ),

                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 10),

                        const _MenuTitle('시스템 정보'),
                        _MenuItem(
                          title: '앱 버전',
                          icon: Icons.info_outline,
                          selected: _section == SettingsSection.systemInfo,
                          onTap: () => setState(() => _section = SettingsSection.systemInfo),
                        ),
                      ],
                    ),
                  ),

                  // 우측 내용
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: _buildContent(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_section) {
      case SettingsSection.accountInfo:
        return _AccountInfoView(onLogout: () => _logout(context));
      case SettingsSection.password:
        return const _PasswordChangeView();
      case SettingsSection.withdraw:
        return _WithdrawView(
          onConfirm: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('탈퇴 처리 로직을 연결하세요.')),
            );
          },
        );
      case SettingsSection.mySettings:
        return const _MySettingsView();
      case SettingsSection.systemInfo:
        return const _SystemInfoView();

      case SettingsSection.wardManage:
        return const _WardManageView();
    }
  }
}

/* -------------------- 병동 관리 뷰 -------------------- */

class _WardManageView extends ConsumerWidget {
  const _WardManageView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: 로그인 후 hospitalCode를 전역으로 들고 있으면 그 값으로 교체
    const hospitalCode = 1;

    final asyncWards = ref.watch(wards.wardListProvider);

    return _PanelCard(
      title: '병동 관리',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 상단 액션(추가/새로고침)
          Row(
            children: [
              const Text(
                '병동 목록을 관리합니다.',
                style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('병동 추가'),
                onPressed: () async {
                  final name = await _showTextDialog(
                    context,
                    title: '병동 추가',
                    hint: '예) 3 병동, 중환자실, VIP 실',
                  );
                  if (name == null) return;

                  try {
                    await ref.read(wards.wardRepositoryProvider).createWard(
                      hospitalCode: hospitalCode,
                      categoryName: name,
                    );
                    ref.invalidate(wards.wardListProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('병동이 추가되었습니다: $name')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('병동 추가 실패: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          Expanded(
            child: asyncWards.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  '병동 목록을 불러오지 못했습니다.\n$e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w800),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Text('등록된 병동이 없습니다.', style: TextStyle(fontWeight: FontWeight.w800)),
                  );
                }

                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final w = list[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.apartment_outlined, color: Color(0xFF374151)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              w.categoryName,
                              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF111827)),
                            ),
                          ),

                          // ✅ 이름 수정
                          IconButton(
                            tooltip: '이름 수정',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () async {
                              final nextName = await _showTextDialog(
                                context,
                                title: '병동 이름 수정',
                                initial: w.categoryName,
                                hint: '병동 이름을 입력',
                              );
                              if (nextName == null) return;

                              try {
                                await ref.read(wards.wardRepositoryProvider).updateWard(
                                  hospitalCode: hospitalCode,
                                  hospitalStCode: w.hospitalStCode,
                                  categoryName: nextName,
                                );
                                ref.invalidate(wards.wardListProvider);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('병동 이름이 변경되었습니다: $nextName')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('이름 수정 실패: $e')),
                                  );
                                }
                              }
                            },
                          ),

                          // ✅ 삭제
                          IconButton(
                            tooltip: '삭제',
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: const Text('병동 삭제', style: TextStyle(fontWeight: FontWeight.w900)),
                                  content: Text('정말 "${w.categoryName}" 병동을 삭제하시겠습니까?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('삭제'),
                                    ),
                                  ],
                                ),
                              );

                              if (ok != true) return;

                              try {
                                await ref.read(wards.wardRepositoryProvider).deleteWard(
                                  hospitalCode: hospitalCode,
                                  hospitalStCode: w.hospitalStCode,
                                );
                                ref.invalidate(wards.wardListProvider);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('병동이 삭제되었습니다: ${w.categoryName}')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('삭제 실패: $e')),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Future<String?> _showTextDialog(
      BuildContext context, {
        required String title,
        String? initial,
        required String hint,
      }) async {
    final ctrl = TextEditingController(text: initial ?? '');

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (_) {
            final v = ctrl.text.trim();
            if (v.isEmpty) return;
            Navigator.pop(ctx, v);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isEmpty) return;
              Navigator.pop(ctx, v);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}

/* -------------------- 이하 기존 UI(마스터님 코드 그대로) -------------------- */

class _MenuTitle extends StatelessWidget {
  final String text;
  const _MenuTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF6B7280)),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final bool danger;
  final VoidCallback onTap;

  const _MenuItem({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFFF3F4F6) : Colors.transparent;
    final fg = danger ? const Color(0xFFEF4444) : (selected ? const Color(0xFF111827) : const Color(0xFF374151));

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: selected ? Border.all(color: const Color(0xFFE5E7EB)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: fg)),
            ),
            if (selected) const Icon(Icons.chevron_right, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _PanelCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _AccountInfoView extends StatelessWidget {
  final Future<void> Function() onLogout;

  const _AccountInfoView({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: '회원정보',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _InfoRow(label: '아이디', value: 'master01'),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('로그아웃'),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('로그아웃'),
                    content: const Text('로그아웃 하시겠습니까?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('로그아웃')),
                    ],
                  ),
                );
                if (ok == true) await onLogout();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordChangeView extends StatelessWidget {
  const _PasswordChangeView();

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: '비밀번호 변경',
      child: Column(
        children: [
          const SizedBox(height: 12),
          TextField(
            obscureText: true,
            decoration: InputDecoration(
              labelText: '새 비밀번호',
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            obscureText: true,
            decoration: InputDecoration(
              labelText: '새 비밀번호 확인',
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('비밀번호 변경 로직을 연결하세요.')),
                );
              },
              child: const Text('변경'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WithdrawView extends StatelessWidget {
  final VoidCallback onConfirm;
  const _WithdrawView({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: '회원 탈퇴',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '탈퇴 시 계정 및 데이터가 삭제될 수 있습니다.\n이 작업은 되돌릴 수 없습니다.',
            style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('회원 탈퇴'),
                    content: const Text('정말 탈퇴하시겠습니까?\n탈퇴 후에는 계정을 복구할 수 없습니다.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('탈퇴'),
                      ),
                    ],
                  ),
                );
                if (ok == true) onConfirm();
              },
              child: const Text('탈퇴하기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MySettingsView extends StatelessWidget {
  const _MySettingsView();

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: '내 설정',
      child: Column(
        children: const [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.tune),
            title: Text('설정 항목 준비중', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('추가 설정이 들어갈 예정입니다.'),
          ),
        ],
      ),
    );
  }
}

class _SystemInfoView extends StatelessWidget {
  const _SystemInfoView();

  @override
  Widget build(BuildContext context) {
    const appVersion = '1.0.0';

    return _PanelCard(
      title: '시스템 정보',
      child: Column(
        children: const [
          _InfoRow(label: '앱 버전', value: appVersion),
          SizedBox(height: 10),
          _InfoRow(label: '서버 상태', value: '정상'),
          SizedBox(height: 10),
          _InfoRow(label: '최근 동기화', value: '방금 전'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w800)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}
