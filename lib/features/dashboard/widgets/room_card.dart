import 'package:flutter/material.dart';
import 'bed_tile.dart'; //


/// 명세: /api/hospital/structure?hospital_st_code=4


class FloorStructureRoom {
  final int hospitalStCode; // room hospital_st_code
  final String categoryName; // "101호"
  final int sortOrder;
  final List<FloorStructureBed> beds;

  const FloorStructureRoom({
    required this.hospitalStCode,
    required this.categoryName,
    required this.sortOrder,
    required this.beds,
  });

  factory FloorStructureRoom.fromJson(Map<String, dynamic> j) {
    final bedsAny = j['beds'];
    final bedsList = (bedsAny is List) ? bedsAny : const [];

    return FloorStructureRoom(
      hospitalStCode: int.tryParse(j['hospital_st_code']?.toString() ?? '') ?? -1,
      categoryName: (j['category_name']?.toString() ?? '').trim(),
      sortOrder: int.tryParse(j['sort_order']?.toString() ?? '') ?? 0,
      beds: bedsList
          .whereType<Map>()
          .map((e) => FloorStructureBed.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
    );
  }

  int get occupiedCount => beds.where((b) => b.patient != null).length;
}

class FloorStructureBed {
  final int hospitalStCode; // bed hospital_st_code
  final String categoryName; // "Bed-1"
  final int sortOrder;
  final BedPatientItem? patient;

  const FloorStructureBed({
    required this.hospitalStCode,
    required this.categoryName,
    required this.sortOrder,
    required this.patient,
  });

  factory FloorStructureBed.fromJson(Map<String, dynamic> j) {
    final pAny = j['patient'];
    final pMap = (pAny is Map) ? Map<String, dynamic>.from(pAny) : null;

    return FloorStructureBed(
      hospitalStCode: int.tryParse(j['hospital_st_code']?.toString() ?? '') ?? -1,
      categoryName: (j['category_name']?.toString() ?? '').trim(),
      sortOrder: int.tryParse(j['sort_order']?.toString() ?? '') ?? 0,
      patient: (pMap == null)
          ? null
          : BedPatientItem(
        patientCode: int.tryParse(pMap['patient_code']?.toString() ?? '') ?? -1,
        patientName: (pMap['patient_name']?.toString() ?? '').trim(),
        patientAge: int.tryParse(pMap['patient_age']?.toString() ?? '') ?? 0,
        patientWarning: int.tryParse(pMap['patient_warning']?.toString() ?? '') ?? 0,
      ),
    );
  }

  int get bedNo => _parseNumber(categoryName) ?? 1;

  static int? _parseNumber(String s) {
    final m = RegExp(r'\d+').firstMatch(s);
    if (m == null) return null;
    return int.tryParse(m.group(0) ?? '');
  }
}

/// ===============================
/// RoomCard (UI)
/// - room: FloorStructureRoom
/// - onEmptyBedTap: 빈 침대 클릭 시
/// - onPatientTap: 환자 클릭 시 (patient_code 기반으로 상세/수정 연결 가능)
/// ===============================

class RoomCard extends StatefulWidget {
  final FloorStructureRoom room;

  /// 빈 침대 눌렀을 때: (room, bed) 넘어오게 해두면
  /// 나중에 "환자 추가 다이얼로그 + bed_code" 연결하기 편합니다.
  final Future<void> Function(FloorStructureRoom room, FloorStructureBed bed)? onEmptyBedTap;

  /// 환자 눌렀을 때: patient_code로 /api/patient/profile?patient_code=... 호출해서 상세 띄우기 좋음
  final Future<void> Function(BedPatientItem patient)? onPatientTap;

  const RoomCard({
    super.key,
    required this.room,
    this.onEmptyBedTap,
    this.onPatientTap,
  });

  @override
  State<RoomCard> createState() => _RoomCardState();
}

class _RoomCardState extends State<RoomCard> {
  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final beds = room.beds;
    final occupied = room.occupiedCount;
    final totalBeds = beds.length;

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
          Text(
            '호실 ${room.categoryName}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            '입원 환자: $occupied/$totalBeds',
            style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Container(height: 2, color: const Color(0xFF111827)),
          const SizedBox(height: 14),

          if (beds.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  '침대 정보가 없습니다.',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w800),
                ),
              ),
            )
          else
            GridView.builder(
              itemCount: beds.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.05,
              ),
              itemBuilder: (context, i) {
                final bed = beds[i];
                final bedNo = bed.bedNo;
                final patient = bed.patient;

                return BedTile(
                  bedNo: bedNo,
                  patient: patient,
                  onTap: () async {
                    if (patient != null) {
                      if (widget.onPatientTap != null) {
                        await widget.onPatientTap!(patient);
                      } else {
                        // 연결 전 기본 동작(크래시 방지)
                        _simpleInfoDialog(context, patient);
                      }
                    } else {
                      if (widget.onEmptyBedTap != null) {
                        await widget.onEmptyBedTap!(room, bed);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('빈 침대입니다. (환자 추가 로직을 연결하세요)')),
                        );
                      }
                    }
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  void _simpleInfoDialog(BuildContext context, BedPatientItem p) {
    const border = Color(0xFFE5E7EB);
    const text = Color(0xFF111827);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: border),
        ),
        title: const Text(
          '환자 정보',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: text),
        ),
        content: Text(
          '${p.patientName} (${p.patientAge}세)\npatient_code: ${p.patientCode}',
          style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4, color: text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
