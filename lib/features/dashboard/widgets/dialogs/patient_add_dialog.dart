import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'package:medicalapp/urlConfig.dart';
import 'package:medicalapp/storage_keys.dart';

class PatientAddDialog extends StatefulWidget {
  final int? prefillBedCode;      // ✅ 침대 hospital_st_code (bed_code)
  final String? prefillRoomLabel; // "101호" (표시용)
  final String? prefillBedLabel;  // "Bed-1" (표시용)

  const PatientAddDialog({
    super.key,
    this.prefillBedCode,
    this.prefillRoomLabel,
    this.prefillBedLabel,
  });

  @override
  State<PatientAddDialog> createState() => _PatientAddDialogState();
}

class _PatientAddDialogState extends State<PatientAddDialog> {
  static const _storage = FlutterSecureStorage();

  // 기본정보
  final nameCtrl = TextEditingController();
  final ageCtrl = TextEditingController();
  final birthCtrl = TextEditingController();
  String gender = '남';
  DateTime? birthDate;

  // 진료정보
  final diagnosisCtrl = TextEditingController();
  final doctorCtrl = TextEditingController();
  final nurseCtrl = TextEditingController();
  final allergyCtrl = TextEditingController();
  final significantCtrl = TextEditingController(); // ✅ 명세 significant

  bool loadingBeds = true;
  bool saving = false;

  int? floorStCode; // 선택된 층 hospital_st_code (스토리지에서)
  List<_BedOption> bedOptions = [];
  int? selectedBedCode;

  @override
  void initState() {
    super.initState();
    _initBeds();
  }

  Future<void> _initBeds() async {
    setState(() => loadingBeds = true);

    // 1) 현재 선택된 층 코드(= floor hospital_st_code) 읽기
    final stStr = await _storage.read(key: StorageKeys.selectedFloorStCode);
    floorStCode = int.tryParse((stStr ?? '').trim());

    if (floorStCode == null) {
      // 층 선택이 안 되어있으면 빈 상태
      bedOptions = [];
      selectedBedCode = null;
      setState(() => loadingBeds = false);
      return;
    }

    // 2) 구조 API에서 rooms/beds 읽어서 "빈 침대"만 옵션으로 만들기
    try {
      final base = Urlconfig.serverUrl;
      final uri = Uri.parse('$base/api/hospital/structure?hospital_st_code=$floorStCode');

      final res = await http.get(uri, headers: {'Content-Type': 'application/json'});
      final decoded = jsonDecode(res.body);

      if (decoded is! Map<String, dynamic> || decoded['code'] != 1) {
        bedOptions = [];
        selectedBedCode = null;
        setState(() => loadingBeds = false);
        return;
      }

      final data = decoded['data'];
      final roomsAny = (data is Map<String, dynamic>) ? data['rooms'] : null;
      final rooms = (roomsAny is List) ? roomsAny : const [];

      final opts = <_BedOption>[];

      for (final rAny in rooms) {
        if (rAny is! Map) continue;
        final r = Map<String, dynamic>.from(rAny);

        final roomLabel = (r['category_name']?.toString() ?? '').trim(); // "101호"
        final bedsAny = r['beds'];
        final beds = (bedsAny is List) ? bedsAny : const [];

        for (final bAny in beds) {
          if (bAny is! Map) continue;
          final b = Map<String, dynamic>.from(bAny);

          final bedCode = int.tryParse(b['hospital_st_code']?.toString() ?? '');
          if (bedCode == null) continue;

          final bedLabel = (b['category_name']?.toString() ?? '').trim(); // "Bed-1"

          // patient가 있으면 점유(추가 불가)
          final hasPatient = b['patient'] is Map;

          if (!hasPatient) {
            opts.add(_BedOption(
              bedCode: bedCode,
              roomLabel: roomLabel,
              bedLabel: bedLabel,
            ));
          }
        }
      }

      // 정렬(방/침대 숫자 기준)
      opts.sort((a, b) {
        final ar = _digits(a.roomLabel);
        final br = _digits(b.roomLabel);
        if (ar != br) return ar.compareTo(br);
        final ab = _digits(a.bedLabel);
        final bb = _digits(b.bedLabel);
        return ab.compareTo(bb);
      });

      bedOptions = opts;

      // prefillBedCode가 있으면 우선 선택
      if (widget.prefillBedCode != null && opts.any((e) => e.bedCode == widget.prefillBedCode)) {
        selectedBedCode = widget.prefillBedCode;
      } else {
        selectedBedCode = opts.isNotEmpty ? opts.first.bedCode : null;
      }
    } catch (_) {
      bedOptions = [];
      selectedBedCode = null;
    }

    setState(() => loadingBeds = false);
  }

  int _digits(String s) {
    final m = RegExp(r'\d+').firstMatch(s);
    return int.tryParse(m?.group(0) ?? '') ?? 0;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    ageCtrl.dispose();
    birthCtrl.dispose();
    diagnosisCtrl.dispose();
    doctorCtrl.dispose();
    nurseCtrl.dispose();
    allergyCtrl.dispose();
    significantCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = nameCtrl.text.trim();
    final age = int.tryParse(ageCtrl.text.trim());
    final diag = diagnosisCtrl.text.trim();
    final doctor = doctorCtrl.text.trim();
    final nurse = nurseCtrl.text.trim();
    final allergy = allergyCtrl.text.trim();
    final significant = significantCtrl.text.trim();
    final bedCode = selectedBedCode;

    if (name.isEmpty || age == null || birthDate == null || diag.isEmpty || doctor.isEmpty || significant.isEmpty) {
      _snack('필수 항목(환자명/나이/생년월일/진단명/주치의/특이사항)을 확인해 주세요.');
      return;
    }
    if (bedCode == null) {
      _snack('배정할 침대를 선택할 수 없습니다. (빈 침대 없음/층 선택 필요)');
      return;
    }

    // 명세 birth_date 예: "890214" 형태로 맞춤(YYMMDD)
    final yy = (birthDate!.year % 100).toString().padLeft(2, '0');
    final mm = birthDate!.month.toString().padLeft(2, '0');
    final dd = birthDate!.day.toString().padLeft(2, '0');
    final birthYyMmDd = '$yy$mm$dd';

    final genderInt = (gender == '남') ? 0 : 1;

    setState(() => saving = true);

    try {
      final base = Urlconfig.serverUrl;
      final uri = Uri.parse('$base/api/patient/profile');

      final token = await _storage.read(key: 'access_token'); //토큰

      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "patient_name": name,
          "gender": genderInt,
          "age": age,
          "birth_date": birthYyMmDd,
          "bed_code": bedCode,
          "nurse": nurse,
          "doctor": doctor,
          "diagnosis": diag,
          "allergy": allergy,
          "significant": significant,
        }),
      );

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic> || decoded['code'] != 1) {
        _snack('환자 추가 실패');
        setState(() => saving = false);
        return;
      }

      // ✅ 성공 → 호출한 쪽에서 재호출(loadData) 할 수 있게 true 반환
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _snack('요청 실패: $e');
      setState(() => saving = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }


  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFE5E7EB);
    const text = Color(0xFF111827);
    const subText = Color(0xFF6B7280);
    const green = Color(0xFF22C55E);

    final bedDropdownItems = bedOptions
        .map((e) => DropdownMenuItem<int>(
      value: e.bedCode,
      child: Text('${e.roomLabel} · ${e.bedLabel}', style: const TextStyle(fontWeight: FontWeight.w800)),
    ))
        .toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        width: 720,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
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
                  Text('환자 추가', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: text)),
                ],
              ),
            ),
            const Divider(height: 1, color: border),

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
                      title: '침대 배정',
                      child: Column(
                        children: [
                          if (floorStCode == null)
                            const Text(
                              '선택된 층이 없습니다. (층 선택 후 다시 시도)',
                              style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w800),
                            )
                          else if (loadingBeds)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          else if (bedOptions.isEmpty)
                              const Text(
                                '빈 침대가 없습니다.',
                                style: TextStyle(color: subText, fontWeight: FontWeight.w800),
                              )
                            else
                              DropdownButtonFormField<int>(
                                value: selectedBedCode,
                                items: bedDropdownItems,
                                onChanged: (v) => setState(() => selectedBedCode = v),
                                decoration: _inputDeco(),
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
                            right: _TextField(label: '주치의', controller: doctorCtrl, requiredMark: true),
                          ),
                          const SizedBox(height: 12),
                          _Row2(
                            left: _TextField(label: '담당 간호사', controller: nurseCtrl),
                            right: _TextField(label: '알레르기', controller: allergyCtrl),
                          ),
                          const SizedBox(height: 12),
                          _TextArea(label: '특이사항(필수)', controller: significantCtrl, requiredMark: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: border),

            // 하단 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end, // ✅ 왼쪽
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    ),
                    onPressed: saving ? null : _save,
                    child: saving
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Text('추가', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    ),
                    onPressed: saving ? null : () => Navigator.pop(context, false),
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

class _BedOption {
  final int bedCode;
  final String roomLabel;
  final String bedLabel;

  const _BedOption({
    required this.bedCode,
    required this.roomLabel,
    required this.bedLabel,
  });
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
  final bool requiredMark;

  const _TextArea({
    required this.label,
    required this.controller,
    this.requiredMark = false,
  });

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      label: label,
      requiredMark: requiredMark,
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
  final void Function(T v) onChanged;
  final bool requiredMark;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
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
              child: Text(it.toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
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
