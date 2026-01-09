// patient_detail_dialog.dart
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'package:medicalapp/urlConfig.dart';
import 'patient_edit_dialog.dart';

class PatientDetailDialog extends ConsumerStatefulWidget {
  final int patientCode;

  /// UI 표시용(호실/침대 라벨) - room_card에서 넘기면 기존 UI 그대로 표현 가능
  final String? roomLabel; // 예: "101호"
  final String? bedLabel; // 예: "Bed-1"

  /// 필요하면 부모 새로고침 연결
  final Future<void> Function()? onRefresh;

  const PatientDetailDialog({
    super.key,
    required this.patientCode,
    this.roomLabel,
    this.bedLabel,
    this.onRefresh,
  });

  @override
  ConsumerState<PatientDetailDialog> createState() => _PatientDetailDialogState();
}

class _PatientDetailDialogState extends ConsumerState<PatientDetailDialog> {
  static const _storage = FlutterSecureStorage();

  late final String _front_url;

  bool _loading = true;
  bool _deleting = false;

  PatientProfileDto? _profile; // ✅ GET /api/patient/profile 결과

  // ✅ 측정값(그래프 + 상단 값)
  List<MeasurementBasicDto> _measurements = const [];

  // ✅ 명세: /api/measurement/basic?device_code=...&patient_code=...
  int _deviceCode = 1;

  @override
  void initState() {
    super.initState();
    _front_url = Urlconfig.serverUrl.toString();
    loadData();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<Map<String, String>> _headers() async {
    final token = await _storage.read(key: 'access_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.trim().isNotEmpty) 'Authorization': 'Bearer ${token.trim()}',
    };
  }

  Future<void> loadData() async {
    setState(() => _loading = true);
    try {
      await getData();
    } catch (e) {
      _snack('로딩 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// ✅ StorageKeys/selected_patient_code 완전 제거 버전
  /// - patientCode는 widget.patientCode만 사용
  /// - deviceCode는 profile의 device_code로 세팅
  Future<void> getData() async {
    final patientCode = widget.patientCode;

    // 다이얼로그가 patientCode 없이 열리면 표시 불가
    if (patientCode <= 0) {
      _profile = null;
      _measurements = const [];
      return;
    }

    // 1) 프로필 먼저 조회 (여기서 device_code 얻음)
    _profile = await _fetchPatientProfile(patientCode);

    final dc = _profile?.deviceCode;
    if (dc != null && dc > 0) {
      _deviceCode = dc;
    }

    // 2) 측정값 조회 (없으면 빈 리스트 반환하도록 처리)
    _measurements = await _fetchMeasurementBasic(
      deviceCode: _deviceCode,
      patientCode: patientCode,
    );

    // 서버가 응답 항목에 device_code를 내려주면 내부 값 갱신(구조/UI 변화 없음)
    if (_measurements.isNotEmpty) {
      _deviceCode = _measurements.last.deviceCode;
    }
  }

  MeasurementBasicDto? get _latestMeasurement {
    if (_measurements.isEmpty) return null;
    return _measurements.last;
  }

  String _vitalValueOrDash({
    required double? value,
    required String unit,
    required int frac,
  }) {
    if (value == null) return '-';
    return '${value.toStringAsFixed(frac)}$unit';
  }

  // =========================
  // ✅ API (명세 반영)
  // =========================

  /// GET /api/patient/profile?patient_code=1
  Future<PatientProfileDto> _fetchPatientProfile(int patientCode) async {
    final uri = Uri.parse('$_front_url/api/patient/profile?patient_code=$patientCode');
    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('환자정보 조회 실패(HTTP ${res.statusCode})');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) throw Exception('환자정보 조회 응답 형식 오류');
    if (decoded['code'] != 1) throw Exception((decoded['message'] ?? '환자정보 조회 실패').toString());

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) throw Exception('환자정보 조회 data 형식 오류');

    return PatientProfileDto.fromJson(data);
  }

  /// baseUrl에 /api 포함/미포함 섞여도 안전하게 합치기
  String _apiUrl(String pathAndQuery) {
    final base = _front_url.trim().replaceAll(RegExp(r'/+$'), ''); // 끝 / 제거
    final p = pathAndQuery.startsWith('/') ? pathAndQuery : '/$pathAndQuery';

    // base가 .../api 로 끝나고, p가 /api/... 로 시작하면 /api 중복 제거
    if (base.toLowerCase().endsWith('/api') && p.toLowerCase().startsWith('/api/')) {
      return base + p.substring(4); // '/api' 제거
    }
    return base + p;
  }

  /// GET /api/measurement/basic?device_code=1&patient_code=1
  /// - 서버가 "측정 데이터 없음"을 404 + {code:-1,...}로 주는 케이스는 빈 리스트로 처리
  Future<List<MeasurementBasicDto>> _fetchMeasurementBasic({
    required int deviceCode,
    required int patientCode,
  }) async {
    final url = _apiUrl('/api/measurement/basic?device_code=$deviceCode&patient_code=$patientCode');
    final uri = Uri.parse(url);

    debugPrint('[MEASUREMENT] GET $uri');
    final res = await http.get(uri, headers: await _headers());
    debugPrint('[MEASUREMENT] status=${res.statusCode} body=${res.body}');

    // ✅ 측정 데이터 없음(서버가 404로 주는 경우) => 에러로 치지 않고 빈 값 처리
    if (res.statusCode == 404) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          final code = int.tryParse(decoded['code']?.toString() ?? '');
          if (code == -1) return const <MeasurementBasicDto>[];
        }
      } catch (_) {
        // body 파싱 실패면 아래에서 일반 에러 처리
      }
      throw Exception('측정값 조회 실패(HTTP 404)\n$uri');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('측정값 조회 실패(HTTP ${res.statusCode})\n$uri');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) throw Exception('측정값 조회 응답 형식 오류');
    if (decoded['code'] != 1) {
      // code=-1 등도 여기로 올 수 있으니, 측정없음은 빈 리스트로 처리(HTTP 200으로 내려오는 경우 대비)
      final c = int.tryParse(decoded['code']?.toString() ?? '');
      if (c == -1) return const <MeasurementBasicDto>[];
      throw Exception((decoded['message'] ?? '측정값 조회 실패').toString());
    }

    final data = decoded['data'];
    if (data is! List) throw Exception('측정값 조회 data 형식 오류');

    final list = data.whereType<Map<String, dynamic>>().map(MeasurementBasicDto.fromJson).toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  /// DELETE /api/patient/profile/delete/{patient_code}
  Future<void> _deletePatient(int patientCode) async {
    final uri = Uri.parse('$_front_url/api/patient/profile/delete/$patientCode');
    final res = await http.delete(uri, headers: await _headers());

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('환자정보 삭제 실패(HTTP ${res.statusCode})');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) throw Exception('환자정보 삭제 응답 형식 오류');
    if (decoded['code'] != 1) throw Exception((decoded['message'] ?? '환자정보 삭제 실패').toString());
  }

  // =========================
  // ✅ UI에 맞는 표시용 모델(레이아웃은 그대로, 데이터만 매핑)
  // =========================

  PatientUi get _ui {
    final api = _profile;

    // ✅ UI가 "호실 ${roomNo} · 침대 ${bedNo}"로 고정이라,
    // roomNo/bedNo는 최대한 짧게(숫자) 만들어야 ... 방지됨
    final roomNo = _compactRoom(widget.roomLabel ?? '');
    final bedNo = _compactBed(widget.bedLabel ?? '', api?.bedCode);

    return PatientUi(
      patientCode: widget.patientCode,
      name: (api?.patientName ?? '').trim(),
      age: api?.age ?? 0,
      roomNo: roomNo,
      bedNo: bedNo,
      nurse: (api?.nurse ?? '').toString(),
      diagnosis: (api?.diagnosis ?? '').toString(),
      physician: (api?.doctor ?? '').toString(),
      allergy: (api?.allergy ?? '').toString(),
      note: (api?.significant ?? '').toString(),
      bedCode: api?.bedCode ?? 0,
    );
  }

  String _compactRoom(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '-';
    final n = _parseDigits(s);
    if (n != null) return n.toString();
    return (s.length > 6) ? s.substring(0, 6) : s;
  }

  String _compactBed(String raw, int? fallbackBedCode) {
    final s = raw.trim();
    final n = _parseDigits(s);
    if (n != null) return n.toString();
    if (s.isEmpty && fallbackBedCode != null && fallbackBedCode > 0) {
      return fallbackBedCode.toString();
    }
    return s.isEmpty ? '-' : ((s.length > 6) ? s.substring(0, 6) : s);
  }

  int? _parseDigits(String s) {
    final m = RegExp(r'\d+').firstMatch(s);
    if (m == null) return null;
    return int.tryParse(m.group(0) ?? '');
  }

  // =========================
  // ✅ 그래프 시리즈 생성 (10분 간격 30개)
  // ✅ 더미 완전 제거: 데이터 없으면 points 비워서 "빈 그래프"
  // =========================

  _ChartSeries _seriesFromMeasurements({
    required String title,
    required String unit,
    required double yMin,
    required double yMax,
    required Color lineColor,
    required Color dotColor,
    required double Function(MeasurementBasicDto m) pick,
  }) {
    final sorted = [..._measurements]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // ✅ 더미 제거: 데이터 없으면 "빈 그래프"
    if (sorted.isEmpty) {
      return _ChartSeries(
        title: title,
        unit: unit,
        points: const <_ChartPoint>[],
        yMin: yMin,
        yMax: yMax,
        lineColor: lineColor,
        dotColor: dotColor,
        selectedDotColor: const Color(0xFF34D399),
      );
    }

    // 최신 쪽 위주(과도한 데이터 방지)
    final src = sorted.length > 200 ? sorted.sublist(sorted.length - 200) : sorted;

    const step = Duration(minutes: 10);
    const stepMs = 10 * 60 * 1000;

    DateTime floorTo10Min(DateTime d) {
      final m = (d.minute ~/ 10) * 10;
      return DateTime(d.year, d.month, d.day, d.hour, m);
    }

    // 끝 시간을 10분 단위로 맞춤
    final end = floorTo10Min(src.last.createdAt);
    final start = end.subtract(step * 29);

    // 10분 버킷 key -> 그 구간의 "마지막 값"
    final bucket = <int, double>{};
    for (final m in src) {
      final t = floorTo10Min(m.createdAt);
      final key = t.millisecondsSinceEpoch ~/ stepMs;
      bucket[key] = pick(m); // 같은 버킷이면 마지막 값으로 덮어씀
    }

    // 초기값: start 이전 가장 가까운 값(없으면 첫 값)
    double cur = pick(src.first);
    for (final m in src) {
      if (m.createdAt.isBefore(start) || m.createdAt.isAtSameMomentAs(start)) {
        cur = pick(m);
      } else {
        break;
      }
    }

    final pts = <_ChartPoint>[];
    for (int i = 0; i < 30; i++) {
      final t = start.add(step * i);
      final key = t.millisecondsSinceEpoch ~/ stepMs;
      if (bucket.containsKey(key)) cur = bucket[key]!;
      final v = cur.clamp(yMin, yMax).toDouble();
      pts.add(_ChartPoint(t, v));
    }

    return _ChartSeries(
      title: title,
      unit: unit,
      points: pts,
      yMin: yMin,
      yMax: yMax,
      lineColor: lineColor,
      dotColor: dotColor,
      selectedDotColor: const Color(0xFF34D399),
    );
  }

  // =========================
  // Actions
  // =========================

  Future<void> _onDischarge() async {
    if (_deleting) return;

    final p = _ui;

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
          '${p.name} 환자를 퇴원 처리하면 목록에서 제거됩니다.',
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

    setState(() => _deleting = true);
    try {
      await _deletePatient(widget.patientCode);

      if (widget.onRefresh != null) {
        await widget.onRefresh!();
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _snack('퇴원 실패: $e');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _onEdit() async {
    final p = _ui;

    await showDialog(
      context: context,
      builder: (_) => PatientEditDialog(
        patientCode: widget.patientCode,
        fromBedCode: p.bedCode,
        onRefresh: () async {
          await loadData();
          if (widget.onRefresh != null) await widget.onRefresh!();
        },
      ),
    );

    await loadData();
  }

  // =========================
  // Build (✅ UI 그대로)
  // =========================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Dialog(
        backgroundColor: Colors.transparent,
        child: SizedBox(width: 520, height: 220, child: Center(child: CircularProgressIndicator())),
      );
    }

    final p = _ui;
    final latest = _latestMeasurement;

    // ✅ 상단 텍스트(체온/병실온도/습도)도 API 최신값으로
    final bodyTempText = _vitalValueOrDash(value: latest?.bodyTemperature, unit: '°C', frac: 1);
    final roomTempText = _vitalValueOrDash(value: latest?.temperature, unit: ' °C', frac: 1);
    final humidText = _vitalValueOrDash(value: latest?.humidity, unit: '%', frac: 0);

    // ✅ 움직임은 명세 API가 없으므로 더미 없이 표시만 '-' 처리
    const movementText = '-';

    // ✅ 그래프 데이터: 명세 API 기반 (10분 간격 30개, 데이터 없으면 빈 그래프)
    final bodyTempSeries = _seriesFromMeasurements(
      title: '체온',
      unit: '°C',
      yMin: 35,
      yMax: 40,
      lineColor: const Color(0xFFEF4444),
      dotColor: const Color(0xFFB91C1C),
      pick: (m) => m.bodyTemperature,
    );

    final roomTempSeries = _seriesFromMeasurements(
      title: '병실온도',
      unit: '°C',
      yMin: 16,
      yMax: 32,
      lineColor: const Color(0xFF06B6D4),
      dotColor: const Color(0xFF0284C7),
      pick: (m) => m.temperature,
    );

    final humiditySeries = _seriesFromMeasurements(
      title: '습도',
      unit: '%',
      yMin: 0,
      yMax: 100,
      lineColor: const Color(0xFF3B82F6),
      dotColor: const Color(0xFF1D4ED8),
      pick: (m) => m.humidity,
    );

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

                  // ✅ 퇴원 버튼(빨간색) - 명세 DELETE 호출
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444), width: 1.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: _deleting ? null : _onDischarge,
                    child: const Text('퇴원', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),

                  const Spacer(),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: _onEdit,
                    child: const Text('수정', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 10),
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

                    // 바이탈 카드 4개(기존 그대로)
                    Row(
                      children: [
                        Expanded(
                          child: _VitalMiniCard(
                            title: '체온',
                            value: bodyTempText,
                            icon: Icons.thermostat_outlined,
                            iconColor: const Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _VitalMiniCard(
                            title: '병실온도',
                            value: roomTempText,
                            icon: Icons.thermostat_outlined,
                            iconColor: const Color(0xFFDC2626),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _VitalMiniCard(
                            title: '습도',
                            value: humidText,
                            icon: Icons.water_drop_outlined,
                            iconColor: const Color(0xFF0EA5E9),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _VitalMiniCard(
                            title: '움직임',
                            value: movementText,
                            icon: Icons.accessibility_new_outlined,
                            iconColor: const Color(0xFF7C3AED),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ✅ 그래프 영역(원본 그대로)
                    Row(
                      children: [
                        Expanded(
                          child: _GraphCard(
                            title: '체온 그래프',
                            onOpenFull: () => _showChartFullScreen(
                              context,
                              title: '체온 그래프',
                              series: bodyTempSeries,
                            ),
                            child: _StaticLineChart(series: bodyTempSeries),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _GraphCard(
                            title: '병실온도 그래프',
                            onOpenFull: () => _showChartFullScreen(
                              context,
                              title: '병실온도 그래프',
                              series: roomTempSeries,
                            ),
                            child: _StaticLineChart(series: roomTempSeries),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _GraphCard(
                            title: '습도 그래프',
                            onOpenFull: () => _showChartFullScreen(
                              context,
                              title: '습도 그래프',
                              series: humiditySeries,
                            ),
                            child: _StaticLineChart(series: humiditySeries),
                          ),
                        ),
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

// ===============================
// Models (API DTO + UI 모델)
// ===============================

class PatientProfileDto {
  final int patientCode;
  final String patientName;
  final int gender;
  final int? age;
  final String? birthDate;
  final int? bedCode;

  /// ✅ 명세 추가: device_code
  final int? deviceCode;

  final String? nurse;
  final String? doctor;
  final String? diagnosis;
  final String? allergy;
  final String? significant;
  final String? note;
  final String? description;

  const PatientProfileDto({
    required this.patientCode,
    required this.patientName,
    required this.gender,
    this.age,
    this.birthDate,
    this.bedCode,
    this.deviceCode,
    this.nurse,
    this.doctor,
    this.diagnosis,
    this.allergy,
    this.significant,
    this.note,
    this.description,
  });

  factory PatientProfileDto.fromJson(Map<String, dynamic> j) {
    return PatientProfileDto(
      patientCode: int.tryParse(j['patient_code']?.toString() ?? '') ?? -1,
      patientName: (j['patient_name']?.toString() ?? '').trim(),
      gender: int.tryParse(j['gender']?.toString() ?? '') ?? 0,
      age: int.tryParse(j['age']?.toString() ?? ''),
      birthDate: j['birth_date']?.toString(),
      bedCode: int.tryParse(j['bed_code']?.toString() ?? ''),
      deviceCode: int.tryParse(j['device_code']?.toString() ?? ''), // ✅ 추가
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

// ✅ /api/measurement/basic 명세 그대로 매핑
class MeasurementBasicDto {
  final int measurementCode;
  final int deviceCode;
  final int patientCode;
  final double temperature; // 병실온도
  final double bodyTemperature; // 체온
  final double humidity; // 습도
  final DateTime createdAt; // create_at

  const MeasurementBasicDto({
    required this.measurementCode,
    required this.deviceCode,
    required this.patientCode,
    required this.temperature,
    required this.bodyTemperature,
    required this.humidity,
    required this.createdAt,
  });

  factory MeasurementBasicDto.fromJson(Map<String, dynamic> j) {
    int _i(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
    double _d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;

    final rawTime = (j['create_at'] ?? '').toString();
    DateTime parsed;
    try {
      parsed = DateTime.parse(rawTime);
    } catch (_) {
      parsed = DateTime.now();
    }

    return MeasurementBasicDto(
      measurementCode: _i(j['measurement_code']),
      deviceCode: _i(j['device_code']),
      patientCode: _i(j['patient_code']),
      temperature: _d(j['temperature']),
      bodyTemperature: _d(j['body_temperature']),
      humidity: _d(j['humidity']),
      createdAt: parsed,
    );
  }
}

class PatientUi {
  final int patientCode;
  final String name;
  final int age;

  /// 기존 UI가 roomNo/bedNo를 사용하므로 그대로 유지
  final String roomNo;
  final String bedNo;

  final String nurse;
  final String diagnosis;
  final String physician;
  final String allergy;
  final String note;

  /// 수정 다이얼로그에 전달용
  final int bedCode;

  const PatientUi({
    required this.patientCode,
    required this.name,
    required this.age,
    required this.roomNo,
    required this.bedNo,
    required this.nurse,
    required this.diagnosis,
    required this.physician,
    required this.allergy,
    required this.note,
    required this.bedCode,
  });
}

/* ------------------ 이하 UI/차트 코드는 원본 그대로 ------------------ */

class _InfoCardBasic extends StatelessWidget {
  final PatientUi p;
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
  final PatientUi p;
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
        Expanded(
          child: Text(
            kv.k,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
          ),
        ),
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
  final VoidCallback onOpenFull;

  const _GraphCard({
    required this.title,
    required this.child,
    required this.onOpenFull,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpenFull,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
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
                Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                IconButton(
                  tooltip: '확대',
                  onPressed: onOpenFull,
                  icon: const Icon(Icons.open_in_full, size: 18, color: Color(0xFF6B7280)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(height: 180, child: child),
          ],
        ),
      ),
    );
  }
}

// =========================
// 차트 (원본 그대로 + x축 시간표시 HH:mm)
// =========================

class _ChartPoint {
  final DateTime t;
  final double v;
  const _ChartPoint(this.t, this.v);
}

class _ChartSeries {
  final String title;
  final String unit;
  final List<_ChartPoint> points;

  final double yMin;
  final double yMax;

  final Color lineColor;
  final Color dotColor;
  final Color selectedDotColor;

  const _ChartSeries({
    required this.title,
    required this.unit,
    required this.points,
    required this.yMin,
    required this.yMax,
    required this.lineColor,
    required this.dotColor,
    required this.selectedDotColor,
  });
}

class _StaticLineChart extends StatelessWidget {
  final _ChartSeries series;
  const _StaticLineChart({required this.series});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: CustomPaint(
          painter: _LineChartPainter(series: series, selectedIndex: null, showTooltip: false),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _InteractiveLineChart extends StatefulWidget {
  final _ChartSeries series;
  const _InteractiveLineChart({required this.series});

  @override
  State<_InteractiveLineChart> createState() => _InteractiveLineChartState();
}

class _InteractiveLineChartState extends State<_InteractiveLineChart> {
  int? selected;

  void _pick(Offset localPos, Size size) {
    const leftPad = 46.0;
    const rightPad = 16.0;
    final plotW = max(1.0, size.width - leftPad - rightPad);

    final n = widget.series.points.length;
    if (n <= 1) return;

    final x = (localPos.dx - leftPad).clamp(0.0, plotW);
    final t = x / plotW;
    final idx = (t * (n - 1)).round().clamp(0, n - 1);

    setState(() => selected = idx);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _pick(d.localPosition, size),
          onPanDown: (d) => _pick(d.localPosition, size),
          onPanUpdate: (d) => _pick(d.localPosition, size),
          child: RepaintBoundary(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: CustomPaint(
                painter: _LineChartPainter(series: widget.series, selectedIndex: selected, showTooltip: true),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final _ChartSeries series;
  final int? selectedIndex;
  final bool showTooltip;

  _LineChartPainter({
    required this.series,
    required this.selectedIndex,
    required this.showTooltip,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const bg = Color(0xFFFFFFFF);
    const border = Color(0xFFE5E7EB);
    const grid = Color(0xFFE5E7EB);
    const axisText = Color(0xFF9CA3AF);
    const tooltipBg = Color(0xCC111827);

    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    canvas.drawRRect(rrect, Paint()..color = bg);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    const leftPad = 46.0;
    const rightPad = 16.0;
    const topPad = 12.0;
    const bottomPad = 26.0;

    final plot = Rect.fromLTWH(
      leftPad,
      topPad,
      max(1.0, size.width - leftPad - rightPad),
      max(1.0, size.height - topPad - bottomPad),
    );

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;

    const gridCount = 5;
    for (int i = 0; i <= gridCount; i++) {
      final y = plot.top + plot.height * (i / gridCount);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
    }

    // y축 값
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i <= 2; i++) {
      final t = i / 2.0;
      final yVal = series.yMax + (series.yMin - series.yMax) * t;
      final y = plot.top + plot.height * t;
      tp.text = TextSpan(
        text: _fmtNum(yVal),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: axisText),
      );
      tp.layout(maxWidth: leftPad - 6);
      tp.paint(canvas, Offset(6, y - tp.height / 2));
    }

    // x축 시간(HH:mm)
    final n = series.points.length;
    if (n >= 2) {
      final targetLabels = 6;
      final step = max(1, ((n - 1) / (targetLabels - 1)).round());

      for (int i = 0; i < n; i += step) {
        final x = plot.left + plot.width * (i / (n - 1));
        final d = series.points[i].t;
        final label = '${_fmt2(d.hour)}:${_fmt2(d.minute)}';

        tp.text = TextSpan(
          text: label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: axisText),
        );
        tp.layout();
        tp.paint(canvas, Offset(x - tp.width / 2, plot.bottom + 6));
      }
    }

    // 선/점 (데이터 없으면 안그려짐)
    Offset ptToXY(int i) {
      final v = series.points[i].v;
      final t = i / (n - 1);
      final x = plot.left + plot.width * t;

      final yn = ((v - series.yMin) / (series.yMax - series.yMin)).clamp(0.0, 1.0);
      final y = plot.bottom - plot.height * yn;
      return Offset(x, y);
    }

    if (n >= 2) {
      final path = Path();
      final p0 = ptToXY(0);
      path.moveTo(p0.dx, p0.dy);

      for (int i = 1; i < n - 1; i++) {
        final p1 = ptToXY(i);
        final p2 = ptToXY(i + 1);
        final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
        path.quadraticBezierTo(p1.dx, p1.dy, mid.dx, mid.dy);
      }
      final pn = ptToXY(n - 1);
      path.lineTo(pn.dx, pn.dy);

      canvas.drawPath(
        path,
        Paint()
          ..color = series.lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );

      for (int i = 0; i < n; i++) {
        final p = ptToXY(i);
        final isSel = selectedIndex == i;
        canvas.drawCircle(p, isSel ? 6 : 4.2, Paint()..color = series.dotColor);
        canvas.drawCircle(
          p,
          isSel ? 6 : 4.2,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    if (showTooltip && selectedIndex != null && n >= 2 && selectedIndex! >= 0 && selectedIndex! < n) {
      final idx = selectedIndex!;
      final p = ptToXY(idx);
      final t = series.points[idx].t;
      final v = series.points[idx].v;

      final line1 = _fmtDateTime(t);
      final line2 = '${series.title}:${_fmtNum(v)}${series.unit}';

      final textStyle = const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800);
      final tp1 = TextPainter(textDirection: TextDirection.ltr)
        ..text = TextSpan(text: line1, style: textStyle)
        ..layout();
      final tp2 = TextPainter(textDirection: TextDirection.ltr)
        ..text = TextSpan(text: line2, style: textStyle)
        ..layout();

      final w = max(tp1.width, tp2.width) + 18;
      final h = tp1.height + tp2.height + 14;

      var bx = p.dx + 12;
      var by = p.dy - h - 12;

      if (bx + w > size.width - 8) bx = p.dx - w - 12;
      if (by < 8) by = p.dy + 12;
      bx = bx.clamp(8.0, size.width - w - 8);
      by = by.clamp(8.0, size.height - h - 8);

      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, w, h), const Radius.circular(10));
      canvas.drawRRect(rect, Paint()..color = tooltipBg);

      tp1.paint(canvas, Offset(bx + 9, by + 7));
      tp2.paint(canvas, Offset(bx + 9, by + 7 + tp1.height + 2));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.showTooltip != showTooltip;
  }
}

void _showChartFullScreen(BuildContext context, {required String title, required _ChartSeries series}) {
  showDialog(
    context: context,
    barrierColor: const Color(0x99000000),
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Container(
          width: 1100,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [
              BoxShadow(color: Color(0x1A000000), blurRadius: 18, offset: Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('닫기', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(height: 520, child: _InteractiveLineChart(series: series)),
              const SizedBox(height: 10),
              const Text(
                '점을 터치 하면 상세 정보가 표시됩니다.',
                style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _fmtNum(double v) {
  if ((v - v.roundToDouble()).abs() < 1e-9) return v.round().toString();
  return v.toStringAsFixed(1);
}

String _fmt2(int n) => n.toString().padLeft(2, '0');

String _fmtDateTime(DateTime t) {
  return '${t.year}-${_fmt2(t.month)}-${_fmt2(t.day)} ${_fmt2(t.hour)}:${_fmt2(t.minute)}:${_fmt2(t.second)}';
}
