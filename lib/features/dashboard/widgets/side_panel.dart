import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // ✅ 추가 (go_router 쓰는 경우)

import '../providers/ward_providers.dart';
import 'patient_list_card.dart';
import 'dialogs/patient_add_dialog.dart';
import 'dialogs/patient_edit_dialog.dart';
import 'side_panel_action_button.dart';

class SidePanel extends ConsumerStatefulWidget {
  const SidePanel({super.key});

  @override
  ConsumerState<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends ConsumerState<SidePanel> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(sidePanelPatientsProvider);
    final selectedId = ref.watch(selectedPatientIdProvider);

    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        children: [
          // 상단: 환자목록 + 총 인원 + 추가 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '환자 목록',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '총 ${patients.length}명',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      builder: (_) => const PatientAddDialog(),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('추가', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),

          // 탭(전체/위험/주의/안정)
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: _Tabs(),
          ),

          // 리스트 스크롤
          Expanded(
            child: Scrollbar(
              controller: _scrollCtrl,
              thumbVisibility: true,
              child: ListView.separated(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                itemCount: patients.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final p = patients[i];
                  return PatientListCard(
                    patient: p,
                    selected: selectedId == p.id,
                    onTap: () async {
                      ref.read(selectedPatientIdProvider.notifier).state = p.id;
                      await showDialog(
                        context: context,
                        builder: (_) => PatientEditDialog(patient: p),
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // ✅ 여기부터 하단 고정 버튼
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Divider(height: 1, color: Color(0xFFE5E7EB)),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: SidePanelActionButton(
              label: '병동 선택',
              icon: Icons.apartment_rounded,
              onTap: () {
                // ✅ go_router 사용 시 (라우트는 프로젝트에 맞게 변경)
                context.go('/login');

                // ✅ 만약 Navigator를 쓰고 있다면 아래로 바꾸세요
                // Navigator.of(context).pushNamed('/ward-select');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends ConsumerWidget {
  const _Tabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(patientTabProvider);

    Widget chip(String label, PatientTab v) {
      final selected = tab == v;
      return InkWell(
        onTap: () => ref.read(patientTabProvider.notifier).state = v,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? const Color(0xFFE5E7EB) : Colors.transparent,
            ),
          ),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          chip('전체', PatientTab.all),
          const SizedBox(width: 8),
          chip('위험', PatientTab.danger),
          const SizedBox(width: 8),
          chip('주의', PatientTab.warning),
          const SizedBox(width: 8),
          chip('안정', PatientTab.stable),
        ],
      ),
    );
  }
}
