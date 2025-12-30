import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/models/patient.dart';
import '../../providers/ward_providers.dart';

class PatientAddDialog extends ConsumerStatefulWidget {
  final int? prefillRoomNo;
  final int? prefillBedNo;

  const PatientAddDialog({super.key, this.prefillRoomNo, this.prefillBedNo});

  @override
  ConsumerState<PatientAddDialog> createState() => _PatientAddDialogState();
}

class _PatientAddDialogState extends ConsumerState<PatientAddDialog> {
  // 기본정보
  final nameCtrl = TextEditingController();
  final ageCtrl = TextEditingController();
  final birthCtrl = TextEditingController();
  String gender = '남';
  DateTime? birthDate;

  // 병실 배정
  late int floor;
  late String ward;
  int? roomNo;
  int bedNo = 1;

  // 진료정보
  final diagnosisCtrl = TextEditingController();
  final physicianCtrl = TextEditingController();
  final nurseCtrl = TextEditingController();
  final allergyCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  RiskStatus status = RiskStatus.stable;

  @override
  void initState() {
    super.initState();
    floor = ref.read(selectedFloorProvider);
    ward = '${floor}층 병동';

    final rooms = ref.read(roomsProvider);
    roomNo = widget.prefillRoomNo ?? (rooms.isNotEmpty ? rooms.first.roomNo : null);
    bedNo = widget.prefillBedNo ?? 1;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    ageCtrl.dispose();
    birthCtrl.dispose();
    diagnosisCtrl.dispose();
    physicianCtrl.dispose();
    nurseCtrl.dispose();
    allergyCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final floors = ref.watch(floorsProvider);
    final rooms = ref.watch(roomsProvider);

    // 병실 드롭다운 안전값
    final roomItems = rooms.map((r) => r.roomNo).toList();
    if (roomNo == null && roomItems.isNotEmpty) roomNo = roomItems.first;
    if (roomNo != null && roomItems.isNotEmpty && !roomItems.contains(roomNo)) roomNo = roomItems.first;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        width: 720,
        decoration: BoxDecoration(
          color: Colors.white,
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
              padding: const EdgeInsets.fromLTRB(22, 18, 18, 12),
              child: Row(
                children: const [
                  Text('환자 추가', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            // 내용(스크롤)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                child: Column(
                  children: [
                    _Section(
                      title: '기본정보',
                      child: Column(
                        children: [
                          _Row2(
                            left: _TextField(label: '환자명', controller: nameCtrl, requiredMark: true),
                            right: _TextField(label: '나이', controller: ageCtrl, keyboardType: TextInputType.number, requiredMark: true),
                          ),
                          const SizedBox(height: 12),
                          _Row2(
                            left: _Dropdown<String>(
                              label: '성별',
                              value: gender,
                              requiredMark: true,
                              items: const ['남', '여'],
                              onChanged: (v) => setState(() => gender = v),
                            ),
                            right: _DateField(
                              label: '생년월일',
                              controller: birthCtrl,
                              requiredMark: true,
                              onPick: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: birthDate ?? DateTime(now.year - 30, 1, 1),
                                  firstDate: DateTime(1900, 1, 1),
                                  lastDate: now,
                                );
                                if (picked == null) return;
                                setState(() {
                                  birthDate = picked;
                                  birthCtrl.text =
                                  '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    _Section(
                      title: '병실 배정',
                      child: Column(
                        children: [
                          _Row2(
                            left: _Dropdown<int>(
                              label: '층수',
                              value: floor,
                              items: floors,
                              onChanged: (v) {
                                // 층수 변경 시 병동도 함께 변경(동기화)
                                ref.read(selectedFloorProvider.notifier).state = v;
                                setState(() {
                                  floor = v;
                                  ward = '${v}층 병동';
                                  final newRooms = ref.read(roomsProvider);
                                  roomNo = newRooms.isNotEmpty ? newRooms.first.roomNo : null;
                                  bedNo = 1;
                                });
                              },
                            ),
                            right: _Dropdown<String>(
                              label: '병동',
                              value: ward,
                              items: floors.map((f) => '${f}층 병동').toList(),
                              onChanged: (v) {
                                // 병동 변경 시 층수도 동기화
                                final parsed = int.tryParse(v.replaceAll('층 병동', ''));
                                if (parsed == null) return;
                                ref.read(selectedFloorProvider.notifier).state = parsed;
                                setState(() {
                                  ward = v;
                                  floor = parsed;
                                  final newRooms = ref.read(roomsProvider);
                                  roomNo = newRooms.isNotEmpty ? newRooms.first.roomNo : null;
                                  bedNo = 1;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          _Row2(
                            left: _Dropdown<int>(
                              label: '호실',
                              value: roomNo ?? (roomItems.isNotEmpty ? roomItems.first : 0),
                              items: roomItems.isNotEmpty ? roomItems : [0],
                              onChanged: (v) => setState(() => roomNo = v),
                            ),
                            right: _Dropdown<int>(
                              label: '침대',
                              value: bedNo,
                              items: List.generate(8, (i) => i + 1),
                              onChanged: (v) => setState(() => bedNo = v),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    _Section(
                      title: '진료정보',
                      child: Column(
                        children: [
                          _Row2(
                            left: _TextField(label: '진단명', controller: diagnosisCtrl, requiredMark: true),
                            right: _TextField(label: '주치의', controller: physicianCtrl, requiredMark: true),
                          ),
                          const SizedBox(height: 12),
                          _Row2(
                            left: _TextField(label: '담당 간호사', controller: nurseCtrl),
                            right: _TextField(label: '알레르기', controller: allergyCtrl),
                          ),
                          const SizedBox(height: 12),
                          _TextArea(label: '특이사항', controller: noteCtrl),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            // 하단 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
              child: Row(
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    ),
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      final age = int.tryParse(ageCtrl.text.trim());
                      final diag = diagnosisCtrl.text.trim();
                      final doc = physicianCtrl.text.trim();

                      if (name.isEmpty || age == null || gender.isEmpty || birthDate == null || diag.isEmpty || doc.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('필수 항목(환자명/나이/성별/생년월일/진단명/주치의)을 확인해 주세요.')),
                        );
                        return;
                      }
                      if (roomNo == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('호실 정보를 확인해 주세요.')),
                        );
                        return;
                      }

                      final id = DateTime.now().millisecondsSinceEpoch.toString();

                      ref.read(patientListProvider.notifier).add(
                        Patient(
                          id: id,
                          name: name,
                          age: age,
                          gender: gender,
                          birthDate: birthDate!,
                          ward: ward,
                          floor: floor,
                          roomNo: roomNo!,
                          bedNo: bedNo,
                          diagnosis: diag,
                          physician: doc,
                          nurse: nurseCtrl.text.trim(),
                          allergy: allergyCtrl.text.trim(),
                          note: noteCtrl.text.trim(),
                          status: RiskStatus.stable,
                        ),
                      );

                      Navigator.pop(context);
                    },
                    child: const Text('추가', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('닫기', style: TextStyle(fontWeight: FontWeight.w900)),
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

/* ------------------ 스타일 위젯(대시보드 톤) ------------------ */

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Row2 extends StatelessWidget {
  final Widget left;
  final Widget right;

  const _Row2({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}

class _TextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool requiredMark;

  const _TextField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.requiredMark = false,
  });

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      label: label,
      requiredMark: requiredMark,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: _inputDeco(),
      ),
    );
  }
}

class _TextArea extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _TextArea({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      label: label,
      child: TextField(
        controller: controller,
        minLines: 3,
        maxLines: 4,
        decoration: _inputDeco(),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool requiredMark;
  final VoidCallback onPick;

  const _DateField({
    required this.label,
    required this.controller,
    required this.onPick,
    this.requiredMark = false,
  });

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      label: label,
      requiredMark: requiredMark,
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(14),
        child: IgnorePointer(
          child: TextField(
            controller: controller,
            decoration: _inputDeco(suffix: const Icon(Icons.calendar_today_outlined, size: 18)),
          ),
        ),
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T v)? itemLabel;
  final void Function(T v) onChanged;
  final bool requiredMark;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLabel,
    this.requiredMark = false,
  });

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      label: label,
      requiredMark: requiredMark,
      child: DropdownButtonFormField<T>(
        value: value,
        items: [
          for (final it in items)
            DropdownMenuItem(
              value: it,
              child: Text(itemLabel?.call(it) ?? it.toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
        ],
        onChanged: (v) {
          if (v == null) return;
          onChanged(v);
        },
        decoration: _inputDeco(),
      ),
    );
  }
}

class _FieldShell extends StatelessWidget {
  final String label;
  final bool requiredMark;
  final Widget child;

  const _FieldShell({required this.label, required this.child, this.requiredMark = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
            if (requiredMark) ...[
              const SizedBox(width: 4),
              const Text('*', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w900)),
            ],
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

InputDecoration _inputDeco({Widget? suffix}) {
  return InputDecoration(
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF93C5FD), width: 2),
    ),
  );
}
