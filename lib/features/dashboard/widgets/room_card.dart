import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ward_providers.dart';
import '../../../domain/models/room.dart';
import 'bed_tile.dart';
import 'dialogs/patient_edit_dialog.dart';
import 'dialogs/patient_add_dialog.dart';

class RoomCard extends ConsumerWidget {
  final Room room;
  const RoomCard({super.key, required this.room});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byRoomBed = ref.watch(patientByRoomBedProvider);
    final map = byRoomBed[room.roomNo] ?? {};
    final occupied = map.length;

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
          Text('호실 ${room.roomNo}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('입원 환자: $occupied/${room.bedCount}', style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Container(height: 2, color: const Color(0xFF111827)),
          const SizedBox(height: 14),

          // 침대 8개(4x2)
          GridView.builder(
            itemCount: room.bedCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.92,
            ),
            itemBuilder: (context, i) {
              final bedNo = i + 1;
              final patient = map[bedNo];

              return BedTile(
                bedNo: bedNo,
                patient: patient,
                onTap: () async {
                  if (patient != null) {
                    await showDialog(context: context, builder: (_) => PatientEditDialog(patient: patient));
                  } else {
                    // 빈 침상 클릭 시: 해당 호실/침상으로 "환자 추가" 바로 열기(실무에서 편함)
                    await showDialog(
                      context: context,
                      builder: (_) => PatientAddDialog(prefillRoomNo: room.roomNo, prefillBedNo: bedNo),
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
