import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'package:medicalapp/urlConfig.dart';
import 'package:medicalapp/storage_keys.dart';

/// ====== API 명세 기반 ======
/// 1) GET    /api/patient/profile?patient_code=1
/// 2) GET    /api/patient/warning?patient_code=1
/// 3) POST   /api/patient/profile/update
/// 4) DELETE /api/patient/profile/delete/{patient_code}
/// 5) POST   /api/patient/bed-history
///
/// Provider 없이: Storage + http + loadData/getData 패턴

class PatientEditDialog extends StatefulWidget {
  final int patientCode;     // 환자 코드
  final int fromBedCode;     // 현재 bed_code (열 때 알고 있어야 함)
  final Future<void> Function()? onRefresh; // 성공 후 부모 재조회

  const PatientEditDialog({
    super.key,
    required this.patientCode,
    required this.fromBedCode,
    this.onRefresh,
  });

  @override
  State<PatientEditDialog> createState() => _PatientEditDialogState();
}

class _PatientEditDialogState extends State<PatientEditDialog> {
  static const _storage = FlutterSecureStorage();
  late final String _frontUrl;

  bool _loading = true;
  String? _error;

  PatientProfile? _profile;
  int _warningState = 0;

  // 현재/선택 bed_code
  late int _currentBedCode;
  int? _pickedBedCode;

  // floor st_code (층 구조 조회용)
  int? _floorStCode;

  // 이동 가능 침대 목록
  bool _bedsLoading = false;
  List<BedOption> _bedOptions = [];

  // 편집 가능한 값(명세 update reqDto)
  final nurseCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  // 침상 이동 기록 reqDto
  final movedReasonCtrl = TextEditingController();
  final movedNoteCtrl = TextEditingController();
  final movedDescCtrl = TextEditingController();

  bool _updating = false;
  bool _moving = false;

  @override
  void initState() {
    super.initState();
    _frontUrl = Urlconfig.serverUrl.toString();
    _currentBedCode = widget.fromBedCode;
    loadData();
  }

  @override
  void dispose() {
    nurseCtrl.dispose();
    noteCtrl.dispose();
    movedReasonCtrl.dispose();
    movedNoteCtrl.dispose();
    movedDescCtrl.dispose();
    super.dispose();
  }

  Map<String, String> get _jsonHeaders => const {'Content-Type': 'application/json'};

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await getData();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> getData() async {
    try {
      // ✅ 대시보드에서 저장해둔 층 st_code(= floor_code) 사용
      final floorStr = await _storage.read(key: StorageKeys.selectedFloorStCode);
      _floorStCode = int.tryParse((floorStr ?? '').trim());

      // 1) 프로필
      _profile = await _fetchPatientProfile(widget.patientCode);

      // bed_code는 서버 값이 있으면 그걸로 동기화
      final bedFromApi = _profile?.bedCode;
      if (bedFromApi != null && bedFromApi > 0) {
        _currentBedCode = bedFromApi;
      }

      // 2) 안전도
      _warningState = await _fetchWarning(widget.patientCode);

      // 3) 편집 필드 초기화(서버 값 기준)
      nurseCtrl.text = (_profile?.nurse ?? '').trim();
      noteCtrl.text = (_profile?.note ?? '').trim();

      // 4) 침대 옵션
      await _loadBedOptions();
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<PatientProfile> _fetchPatientProfile(int patientCode) async {
    final uri = Uri.parse('$_frontUrl/api/patient/profile?patient_code=$patientCode');
    final res = await http.get(uri, headers: _jsonHeaders);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('프로필 조회 실패(HTTP ${res.statusCode})');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) throw Exception('프로필 응답 형식 오류');
    if (decoded['code'] != 1) throw Exception((decoded['message'] ?? '프로필 조회 실패').toString());

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) throw Exception('프로필 data 형식 오류');
    return PatientProfile.fromJson(data);
  }

  Future<int> _fetchWarning(int patientCode) async {
    final uri = Uri.parse('$_frontUrl/api/patient/warning?patient_code=$patientCode');
    final res = await http.get(uri, headers: _jsonHeaders);
    if (res.statusCode < 200 || res.statusCode >= 300) return 0;

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return 0;
    if (decoded['code'] != 1) return 0;

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) return 0;

    return int.tryParse(data['warning_state']?.toString() ?? '') ?? 0;
  }

  Future<void> _loadBedOptions() async {
    if (_floorStCode == null) {
      _bedOptions = [];
      _pickedBedCode = null;
      return;
    }

    setState(() => _bedsLoading = true);
    try {
      // 명세: /api/hospital/structure?hospital_st_code=4 (층 구조)
      final uri = Uri.parse('$_frontUrl/api/hospital/structure?hospital_st_code=$_floorStCode');
      final res = await http.get(uri, headers: _jsonHeaders);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('층 구조 조회 실패(HTTP ${res.statusCode})');
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) throw Exception('층 구조 응답 형식 오류');
      if (decoded['code'] != 1) throw Exception((decoded['message'] ?? '층 구조 조회 실패').toString());

      final data = decoded['data'];
      if (data is! Map<String, dynamic>) throw Exception('층 구조 data 형식 오류');

      final rooms = (data['rooms'] as List?) ?? [];
      final opts = <BedOption>[];

      for (final r in rooms) {
        if (r is! Map) continue;
        final roomName = (r['category_name']?.toString() ?? '').trim(); // "101호"
        final beds = (r['beds'] as List?) ?? [];

        for (final b in beds) {
          if (b is! Map) continue;

          final bedCode = int.tryParse(b['hospital_st_code']?.toString() ?? '');
          final bedName = (b['category_name']?.toString() ?? '').trim(); // "Bed-1"
          if (bedCode == null) continue;

          bool occupied = false;
          final patientAny = b['patient'];
          if (patientAny is Map) {
            final pc = int.tryParse(patientAny['patient_code']?.toString() ?? '');
            if (pc != null && pc > 0) occupied = true;
          }

          final disabled = occupied; // 사용중 침대는 이동 대상에서 제외(원하면 정책 변경 가능)

          opts.add(
            BedOption(
              bedCode: bedCode,
              label: roomName.isEmpty ? bedName : '$roomName · $bedName',
              disabled: disabled,
              occupied: occupied,
            ),
          );
        }
      }

      opts.sort((a, b) => a.label.compareTo(b.label));

      setState(() {
        _bedOptions = opts;
        _pickedBedCode = null; // 새로 불러오면 선택 초기화
      });
    } finally {
      if (mounted) setState(() => _bedsLoading = false);
    }
  }

  // ✅ 환자 정보 수정 API
  Future<PatientProfile> _updatePatientProfile({
    required int patientCode,
    required int bedCode,
    required String nurse,
    String? note,
  }) async {
    final uri = Uri.parse('$_frontUrl/api/patient/profile/update');

    final res = await http.post(
      uri,
      headers: _jsonHeaders,
      body: jsonEncode({
        "patient_code": patientCode,
        "bed_code": bedCode,
        "nurse": nurse,
        "note": (note == null || note.trim().isEmpty) ? null : note.trim(),
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('환자정보 수정 실패(HTTP ${res.statusCode})');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) throw Exception('수정 응답 형식 오류');
    if (decoded['code'] != 1) throw Exception((decoded['message'] ?? '환자정보 수정 실패').toString());

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) throw Exception('수정 data 형식 오류');

    return PatientProfile.fromJson(data);
  }

  // ✅ 침상 이동 기록 API
  Future<void> _createBedHistory({
    required int patientCode,
    required int fromBedCode,
    required int toBedCode,
    required String movedReason,
    String? note,
    String? description,
  }) async {
    final uri = Uri.parse('$_frontUrl/api/patient/bed-history');

    final res = await http.post(
      uri,
      headers: _jsonHeaders,
      body: jsonEncode({
        "patient_code": patientCode,
        "from_bed_code": fromBedCode,
        "to_bed_code": toBedCode,
        "moved_reason": movedReason,
        "note": (note == null || note.trim().isEmpty) ? null : note.trim(),
        "description": (description == null || description.trim().isEmpty) ? null : description.trim(),
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('침상이동 기록 실패(HTTP ${res.statusCode})');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) throw Exception('침상이동 기록 응답 형식 오류');
    if (decoded['code'] != 1) throw Exception((decoded['message'] ?? '침상이동 기록 실패').toString());
  }

  Future<void> _onPressUpdateOnly() async {
    if (_updating) return;

    final nurse = nurseCtrl.text.trim();
    if (nurse.isEmpty) {
      _snack('간호사(nurse)는 필수입니다.');
      return;
    }

    final bedCode = _pickedBedCode ?? _currentBedCode;
    if (bedCode <= 0) {
      _snack('bed_code가 올바르지 않습니다.');
      return;
    }

    setState(() => _updating = true);
    try {
      final updated = await _updatePatientProfile(
        patientCode: widget.patientCode,
        bedCode: bedCode,
        nurse: nurse,
        note: noteCtrl.text,
      );

      setState(() {
        _profile = updated;
        _currentBedCode = updated.bedCode ?? bedCode;
        _pickedBedCode = null;
      });

      _snack('환자정보 수정 성공');
      if (widget.onRefresh != null) await widget.onRefresh!();
    } catch (e) {
      _snack('수정 실패: $e');
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _onPressMoveAndUpdate() async {
    if (_moving) return;

    final toBed = _pickedBedCode;
    if (toBed == null) {
      _snack('이동할 침대를 선택해 주세요.');
      return;
    }
    if (toBed == _currentBedCode) {
      _snack('현재 침대와 다른 침대를 선택해 주세요.');
      return;
    }

    final reason = movedReasonCtrl.text.trim();
    if (reason.isEmpty) {
      _snack('이동 사유(moved_reason)는 필수입니다.');
      return;
    }

    final nurse = nurseCtrl.text.trim();
    if (nurse.isEmpty) {
      _snack('간호사(nurse)는 필수입니다.');
      return;
    }

    setState(() => _moving = true);
    try {
      // 1) 이동 기록 생성
      await _createBedHistory(
        patientCode: widget.patientCode,
        fromBedCode: _currentBedCode,
        toBedCode: toBed,
        movedReason: reason,
        note: movedNoteCtrl.text,
        description: movedDescCtrl.text,
      );

      // 2) 환자정보 수정(침대/간호사/노트 반영)
      final updated = await _updatePatientProfile(
        patientCode: widget.patientCode,
        bedCode: toBed,
        nurse: nurse,
        note: noteCtrl.text,
      );

      setState(() {
        _profile = updated;
        _currentBedCode = updated.bedCode ?? toBed;
        _pickedBedCode = null;
      });

      _snack('침상 이동 + 환자정보 수정 완료');
      if (widget.onRefresh != null) await widget.onRefresh!();

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _snack('침상 이동 실패: $e');
    } finally {
      if (mounted) setState(() => _moving = false);
    }
  }

  Future<void> _onPressDischarge() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
        backgroundColor: const Color(0xFFFAFAFA),
        title: const Text('정말 퇴원하겠습니까?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
          '${_profile?.patientName ?? '해당'} 환자를 퇴원 처리하면 목록에서 제거됩니다.',
          style: const TextStyle(fontWeight: FontWeight.w900, height: 1.4, color: Color(0xFF111827)),
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

    try {
      final uri = Uri.parse('$_frontUrl/api/patient/profile/delete/${widget.patientCode}');
      final res = await http.delete(uri, headers: _jsonHeaders);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('퇴원 실패(HTTP ${res.statusCode})');
      }

      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['code'] != 1) {
        throw Exception((decoded['message'] ?? '퇴원 실패').toString());
      }

      _snack('퇴원 처리 완료');
      if (widget.onRefresh != null) await widget.onRefresh!();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _snack('퇴원 실패: $e');
    }
  }

  Color _riskColor(int w) {
    if (w == 2) return const Color(0xFFEF4444);
    if (w == 1) return const Color(0xFFF59E0B);
    return const Color(0xFF22C55E);
  }

  String _riskLabel(int w) {
    if (w == 2) return '위험';
    if (w == 1) return '주의';
    return '안전';
  }

  Future<Map<String, dynamic>?> _getJson(Uri uri) async {
    final token = await _storage.read(key: 'access_token');

    final res = await http.get(uri, headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    });

    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded;
  }

  Future<Map<String, dynamic>?> _sendJson(
      String method,
      Uri uri, {
        Map<String, dynamic>? body,
      }) async {
    final token = await _storage.read(key: 'access_token');

    final req = http.Request(method, uri);
    req.headers.addAll({
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    });

    if (body != null) req.body = jsonEncode(body);

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode < 200 || res.statusCode >= 300) return null;

    // ✅ delete가 body 없이 올 수도 있으니 방어
    if (res.body.trim().isEmpty) return <String, dynamic>{'code': 1};

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded;
  }


  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Dialog(
        backgroundColor: Colors.transparent,
        child: SizedBox(width: 520, height: 220, child: Center(child: CircularProgressIndicator())),
      );
    }

    if (_error != null) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('오류', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 10),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFEF4444))),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('닫기'))),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton(onPressed: loadData, child: const Text('다시 시도'))),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final p = _profile;
    final riskC = _riskColor(_warningState);
    final riskT = _riskLabel(_warningState);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        width: 780,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 18, 12),
              child: Row(
                children: [
                  const Text('환자 정보 수정', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: riskC.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
                    child: Text(riskT, style: TextStyle(color: riskC, fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                child: Column(
                  children: [
                    _Section(
                      title: '기본정보(조회)',
                      child: Column(
                        children: [
                          _Row2(
                            left: _ReadField(label: '환자명', value: p?.patientName ?? '-'),
                            right: _ReadField(label: '나이', value: p?.age?.toString() ?? '-'),
                          ),
                          const SizedBox(height: 12),
                          _Row2(
                            left: _ReadField(label: '성별', value: (p?.gender == 1) ? '여' : '남'),
                            right: _ReadField(label: '생년월일', value: p?.birthDate ?? '-'),
                          ),
                          const SizedBox(height: 12),
                          _ReadField(label: '진단명', value: p?.diagnosis ?? '-'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    _Section(
                      title: '수정(명세: /api/patient/profile/update)',
                      child: Column(
                        children: [
                          _Row2(
                            left: _ReadField(label: '현재 bed_code', value: _currentBedCode.toString()),
                            right: _TextField(label: '담당 간호사(nurse)*', controller: nurseCtrl, requiredMark: true),
                          ),
                          const SizedBox(height: 12),

                          if (_floorStCode == null)
                            const Text(
                              '층 코드(selectedFloorStCode)가 Storage에 없어 침대 목록을 불러올 수 없습니다.\n'
                                  '대시보드에서 층 선택 시 StorageKeys.selectedFloorStCode를 저장해 주세요.',
                              style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700, height: 1.35),
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: _BedDropdown(
                                    label: '변경할 bed_code(선택)',
                                    value: _pickedBedCode,
                                    loading: _bedsLoading,
                                    items: _bedOptions,
                                    onChanged: (v) => setState(() => _pickedBedCode = v),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton.icon(
                                  onPressed: _bedsLoading ? null : _loadBedOptions,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('새로고침', style: TextStyle(fontWeight: FontWeight.w900)),
                                ),
                              ],
                            ),

                          const SizedBox(height: 12),
                          _TextArea(label: '노트(note)', controller: noteCtrl),

                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF22C55E),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              ),
                              onPressed: _updating ? null : _onPressUpdateOnly,
                              child: _updating
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                                  : const Text('수정 저장', style: TextStyle(fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    _Section(
                      title: '침상 이동 기록(명세: /api/patient/bed-history)',
                      child: Column(
                        children: [
                          _TextField(label: '이동 사유(moved_reason)*', controller: movedReasonCtrl, requiredMark: true),
                          const SizedBox(height: 12),
                          _TextField(label: '메모(note)', controller: movedNoteCtrl),
                          const SizedBox(height: 12),
                          _TextArea(label: '설명(description)', controller: movedDescCtrl),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              onPressed: _moving ? null : _onPressMoveAndUpdate,
                              icon: _moving
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                                  : const Icon(Icons.swap_horiz),
                              label: const Text('이동 기록 + 침대 반영', style: TextStyle(fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE5E7EB)),

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
                    onPressed: () => Navigator.pop(context),
                    child: const Text('닫기', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    ),
                    onPressed: _onPressDischarge,
                    child: const Text('퇴원', style: TextStyle(fontWeight: FontWeight.w900)),
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

/// =====================
/// Models
/// =====================

class PatientProfile {
  final int patientCode;
  final String patientName;
  final int gender; // 0 male, 1 female
  final int? age;
  final String? birthDate;
  final int? bedCode;

  final String? nurse;
  final String? doctor;
  final String? diagnosis;
  final String? allergy;
  final String? significant;

  final String? note;
  final String? description;

  const PatientProfile({
    required this.patientCode,
    required this.patientName,
    required this.gender,
    this.age,
    this.birthDate,
    this.bedCode,
    this.nurse,
    this.doctor,
    this.diagnosis,
    this.allergy,
    this.significant,
    this.note,
    this.description,
  });

  factory PatientProfile.fromJson(Map<String, dynamic> j) {
    return PatientProfile(
      patientCode: int.tryParse(j['patient_code']?.toString() ?? '') ?? -1,
      patientName: (j['patient_name']?.toString() ?? '').trim(),
      gender: int.tryParse(j['gender']?.toString() ?? '') ?? 0,
      age: int.tryParse(j['age']?.toString() ?? ''),
      birthDate: j['birth_date']?.toString(),
      bedCode: int.tryParse(j['bed_code']?.toString() ?? ''),
      nurse: j['nurse']?.toString(),
      doctor: j['doctor']?.toString(),
      diagnosis: j['diagnosis']?.toString(),
      allergy: j['allergy']?.toString(),
      significant: j['significant']?.toString(),
      note: j['note']?.toString(),
      description: j['description']?.toString(),
    );
  }
}

class BedOption {
  final int bedCode;
  final String label;
  final bool disabled;
  final bool occupied;

  const BedOption({
    required this.bedCode,
    required this.label,
    required this.disabled,
    required this.occupied,
  });
}

/// =====================
/// UI Helpers (대시보드 톤)
/// =====================

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

class _ReadField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      label: label,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF111827)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool requiredMark;

  const _TextField({
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

class _BedDropdown extends StatelessWidget {
  final String label;
  final int? value;
  final bool loading;
  final List<BedOption> items;
  final ValueChanged<int?> onChanged;

  const _BedDropdown({
    required this.label,
    required this.value,
    required this.loading,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      label: label,
      child: DropdownButtonFormField<int>(
        value: value,
        items: [
          for (final it in items)
            DropdownMenuItem<int>(
              value: it.disabled ? null : it.bedCode,
              enabled: !it.disabled,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      it.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: it.disabled ? const Color(0xFF9CA3AF) : const Color(0xFF111827),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (it.occupied)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text('사용중', style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w800)),
                    ),
                ],
              ),
            ),
        ],
        onChanged: loading ? null : onChanged,
        decoration: _inputDeco(),
        hint: loading ? const Text('불러오는 중...') : const Text('선택'),
      ),
    );
  }
}

class _FieldShell extends StatelessWidget {
  final String label;
  final bool requiredMark;
  final Widget child;

  const _FieldShell({
    required this.label,
    required this.child,
    this.requiredMark = false,
  });

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
