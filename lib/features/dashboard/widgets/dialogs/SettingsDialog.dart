import 'package:flutter/material.dart';

enum SettingsSection {
  accountInfo,   // 회원정보
  profile,       // 내 프로필
  password,      // 비밀번호 변경
  withdraw,      // 회원 탈퇴
  mySettings,    // 내 설정
  systemInfo,    // 시스템 정보(앱 버전 등)
}

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  SettingsSection _section = SettingsSection.accountInfo; // ✅ 처음 뜨는 화면: 회원정보

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent, // ✅ 환자추가/상세 다이얼로그 스타일과 동일하게
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        width: 1120, // ✅ 환자추가 다이얼로그와 동일하게 맞추세요(필요시 조정)
        height: 720, // ✅ 필요시 조정
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
            // 상단 헤더(타이틀 + 닫기)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 10, 12),
              child: Row(
                children: [
                  const Text(
                    '설정',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // 본문: 좌측 메뉴 + 우측 내용
            Expanded(
              child: Row(
                children: [
                  // 좌측 메뉴
                  Container(
                    width: 300,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        right: BorderSide(color: Color(0xFFE5E7EB)),
                      ),
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
                          title: '내 프로필',
                          icon: Icons.person_outline,
                          selected: _section == SettingsSection.profile,
                          onTap: () => setState(() => _section = SettingsSection.profile),
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
        return const _AccountInfoView();

      case SettingsSection.profile:
        return const _ProfileEditView();

      case SettingsSection.password:
        return const _PasswordChangeView();

      case SettingsSection.withdraw:
        return _WithdrawView(
          onConfirm: () {
            // TODO: 탈퇴 API 연결
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('탈퇴 처리 로직을 연결하세요.')),
            );
          },
        );

      case SettingsSection.mySettings:
        return const _MySettingsView(); // ✅ 다크모드 삭제된 상태

      case SettingsSection.systemInfo:
        return const _SystemInfoView();
    }
  }
}

/* -------------------- 좌측 메뉴 UI -------------------- */

class _MenuTitle extends StatelessWidget {
  final String text;
  const _MenuTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Color(0xFF6B7280),
        ),
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
    final fg = danger
        ? const Color(0xFFEF4444)
        : (selected ? const Color(0xFF111827) : const Color(0xFF374151));

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
              child: Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w800, color: fg),
              ),
            ),
            if (selected) const Icon(Icons.chevron_right, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }
}

/* -------------------- 우측 내용 뷰 -------------------- */

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
          child,
        ],
      ),
    );
  }
}

class _AccountInfoView extends StatelessWidget {
  const _AccountInfoView();

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: '회원정보',
      child: Column(
        children: const [
          _InfoRow(label: '아이디', value: 'master01'),
          SizedBox(height: 10),
          _InfoRow(label: '이메일', value: 'master@example.com'),
          SizedBox(height: 10),
          _InfoRow(label: '가입일', value: '2025-12-01'),
        ],
      ),
    );
  }
}

class _ProfileEditView extends StatelessWidget {
  const _ProfileEditView();

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: '내 프로필',
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              labelText: '이름',
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              labelText: '연락처',
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
                // TODO: 프로필 저장 로직 연결
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('프로필 저장 로직을 연결하세요.')),
                );
              },
              child: const Text('저장'),
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
          TextField(
            obscureText: true,
            decoration: InputDecoration(
              labelText: '현재 비밀번호',
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
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
                // TODO: 비밀번호 변경 로직 연결
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
                  builder: (_) => AlertDialog(
                    title: const Text('회원 탈퇴'),
                    content: const Text('정말 탈퇴하시겠습니까?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('탈퇴')),
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
    // ✅ package_info_plus 없이 일단 고정값(나중에 실값으로 교체)
    const appVersion = '1.0.0';

    return _PanelCard(
      title: '시스템 정보',
      child: Column(
        children: const [
          _InfoRow(label: '앱 버전', value: appVersion),
          SizedBox(height: 10),
          _InfoRow(label: '서버 상태', value: '정상'), // TODO: 서버 헬스체크 연결 가능
          SizedBox(height: 10),
          _InfoRow(label: '최근 동기화', value: '방금 전'), // TODO: 실제 값 연결
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
