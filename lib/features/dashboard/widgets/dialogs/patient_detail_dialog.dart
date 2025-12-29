import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/patient.dart';
import '../../providers/ward_providers.dart';
import 'patient_edit_dialog.dart';





class PatientDetailDialog extends ConsumerWidget {
  final String patientId;
  const PatientDetailDialog({super.key, required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(patientListProvider);
    final p = patients.firstWhere((e) => e.id == patientId);

    final vitalsMap = ref.watch(vitalsProvider);
    final v = vitalsMap[patientId] ?? PatientVitals.mock(); // 더미(없으면)

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        width: 1120,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 18, 12),
              child: Row(
                children: [
                  Text('${p.name} 환자 상세', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 10),
                  // ✅ 퇴원 버튼(빨간색)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444), width: 1.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Text('정말 퇴원하겠습니까?', style: TextStyle(fontWeight: FontWeight.w900)),
                          content: Text(
                            '${p.name} 환자를 퇴원 처리하면 목록에서 제거됩니다.',
                            style: const TextStyle(height: 1.4),
                          ),
                          actions: [
                            OutlinedButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('닫기', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('퇴원', style: TextStyle(fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ),
                      );

                      if (ok != true) return;

                      // ✅ 더미 데이터(환자 목록) 삭제
                      ref.read(patientListProvider.notifier).remove(p.id);

                      // ✅ (선택) 실시간 데이터도 같이 정리하고 싶으면 아래 주석 해제
                      // ref.read(realtimeProvider.notifier).remove(p.id);
                      // ref.read(vitalsProvider.notifier).remove(p.id);

                      // ✅ 상세창 닫기
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('퇴원', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),

                  const Spacer(),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('닫기', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () async {
                      await showDialog(
                        context: context,
                        builder: (_) => PatientEditDialog(patient: p),
                      );
                    },
                    child: const Text('수정', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            // 내용
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 상단 2개 카드(기본/진료)
                    Row(
                      children: [
                        Expanded(child: _InfoCardBasic(p: p)),
                        const SizedBox(width: 18),
                        Expanded(child: _InfoCardMedical(p: p)),
                      ],
                    ),
                    const SizedBox(height: 22),

                    const Text('실시간 바이탈 사인', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 14),





                    // 바이탈 카드 4개
                    Row(
                      children: [
                        Expanded(child: _VitalMiniCard(title: '체온', value: '${v.bodytemp.toStringAsFixed(1)}°C', icon: Icons.thermostat_outlined, iconColor: const Color(0xFF2563EB))),
                        const SizedBox(width: 16),
                        Expanded(child: _VitalMiniCard(title: '병실온도', value: '${v.roomtemp.toStringAsFixed(1)} °C', icon: Icons.thermostat_outlined, iconColor: const Color(0xFFDC2626))),
                        const SizedBox(width: 16),
                        Expanded(child: _VitalMiniCard(title: '습도', value: '${v.humidity.toStringAsFixed(0)}%', icon: Icons.water_drop_outlined, iconColor: const Color(0xFF0EA5E9))),
                        const SizedBox(width: 16),
                        Expanded(child: _VitalMiniCard(title: '움직임', value: '${v.movement.label} ', icon: Icons.accessibility_new_outlined, iconColor: const Color(0xFF7C3AED))),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // 그래프 영역 (우선 “박스”로 자리 잡고, 나중에 실제 그래프 위젯으로 교체)
                    Row(
                      children: [
                        Expanded(child: _GraphCard(title: '체온 추이', child: _PlaceholderGraph())),
                        const SizedBox(width: 16),
                        Expanded(child: _GraphCard(title: '병실온도 추이', child: _PlaceholderGraph())),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _GraphCard(title: '습도 추이', child: _PlaceholderGraph())),
                        const SizedBox(width: 16),
                        Expanded(child: _GraphCard(title: '움직임 추이', child: _PlaceholderGraph())),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----- UI 파츠들 -----

class _InfoCardBasic extends StatelessWidget {
  final Patient p;
  const _InfoCardBasic({required this.p});

  @override
  Widget build(BuildContext context) {
    return _BigCard(
      title: '기본 정보',
      titleIcon: Icons.calendar_today_outlined,
      titleIconColor: const Color(0xFF2563EB),
      rows: [
        _KV('환자명', p.name),
        _KV('나이', '${p.age}세'),
        _KV('병실', '호실 ${p.roomNo} · 침대 ${p.bedNo}'),
        _KV('담당 간호사', p.nurse.isEmpty ? '-' : p.nurse),
      ],
    );
  }
}

class _InfoCardMedical extends StatelessWidget {
  final Patient p;
  const _InfoCardMedical({required this.p});

  @override
  Widget build(BuildContext context) {
    return _BigCard(
      title: '진료 정보',
      titleIcon: Icons.medical_services_outlined,
      titleIconColor: const Color(0xFF16A34A),
      rows: [
        _KV('진단명', p.diagnosis.isEmpty ? '-' : p.diagnosis),
        _KV('주치의', p.physician.isEmpty ? '-' : p.physician),
        _KV('알레르기', p.allergy.isEmpty ? '-' : p.allergy),
        _KV('특이사항', p.note.isEmpty ? '-' : p.note, valueColor: p.note.isEmpty ? null : const Color(0xFFDC2626)),
      ],
    );
  }
}

class _BigCard extends StatelessWidget {
  final String title;
  final IconData titleIcon;
  final Color titleIconColor;
  final List<_KV> rows;

  const _BigCard({
    required this.title,
    required this.titleIcon,
    required this.titleIconColor,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(titleIcon, color: titleIconColor),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 18),
          for (int i = 0; i < rows.length; i++) ...[
            _KVRow(rows[i]),
            if (i != rows.length - 1) const Divider(height: 18, color: Color(0xFFE5E7EB)),
          ],
        ],
      ),
    );
  }
}

class _KV {
  final String k;
  final String v;
  final Color? valueColor;
  _KV(this.k, this.v, {this.valueColor});
}

class _KVRow extends StatelessWidget {
  final _KV kv;
  const _KVRow(this.kv);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(kv.k, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF374151)))),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            kv.v,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kv.valueColor ?? const Color(0xFF111827)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _VitalMiniCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _VitalMiniCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(value, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GraphCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _GraphCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          SizedBox(height: 180, child: child),
        ],
      ),
    );
  }
}

class _PlaceholderGraph extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Center(
        child: Text('그래프 영역(추후 연결)', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w800)),
      ),
    );
  }
}
