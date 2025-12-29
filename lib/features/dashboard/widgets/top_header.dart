import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ward_providers.dart';
import './dialogs/SettingsDialog.dart';

class TopHeader extends ConsumerWidget {
  const TopHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final floors = ref.watch(floorsProvider);
    final selectedFloor = ref.watch(selectedFloorProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('병동 모니터링 시스템', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text('전체 환자 현황 및 건강 상태 관리', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(width: 28),
          const Text('층수:', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: selectedFloor,
                items: [
                  for (final f in floors)
                    DropdownMenuItem(value: f, child: Text('$f층', style: const TextStyle(fontWeight: FontWeight.w800))),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  ref.read(selectedFloorProvider.notifier).state = v;
                  ref.read(selectedPatientIdProvider.notifier).state = null;
                },
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 10),
          _IconWithDot(
            icon: Icons.settings_outlined,
            dot: true,
            onTap: () {showDialog(
                context: context,
                builder: (_) => SettingsDialog()
            );
                },
          ),
        ],
      ),
    );
  }
}

class _IconWithDot extends StatelessWidget {
  final IconData icon;
  final bool dot;
  final VoidCallback onTap;

  const _IconWithDot({required this.icon, required this.dot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(onPressed: onTap, icon: Icon(icon)),
        if (dot)
          const Positioned(
            right: 10,
            top: 10,
            child: CircleAvatar(radius: 4, backgroundColor: Color(0xFFEF4444)),
          ),
      ],
    );
  }
}
