import 'package:flutter/material.dart';
import '../../../domain/models/patient.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ward_providers.dart';
import '../../../domain/models/patient_realtime.dart';

Color statusColor(RiskStatus s) {
  switch (s) {
    case RiskStatus.danger:
      return const Color(0xFFEF4444);
    case RiskStatus.warning:
      return const Color(0xFFF59E0B);
    case RiskStatus.stable:
      return const Color(0xFF22C55E);
  }
}

class PatientListCard extends ConsumerWidget {
  final Patient patient;
  final bool selected;
  final VoidCallback onTap;

  const PatientListCard({
    super.key,
    required this.patient,
    required this.selected,
    required this.onTap,
  });


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rtMap = ref.watch(realtimeProvider);
    final rt = rtMap[patient.id];

    final status = rt?.status ?? patient.status;


    final c = statusColor(status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F2FF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? const Color(0xFF93C5FD) : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: c.withOpacity(0.15),
              child: Icon(Icons.person, color: c, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          patient.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('병상 ${patient.roomNo}-${patient.bedNo}', style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: c.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(statusLabel(status), style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}