import 'dart:math';

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

    // ✅ 그래프용 더미 데이터(3개)
    final bodyTempSeries = _ChartSeries.dummy(
      seed: patientId.hashCode ^ 0xA11CE,
      title: '체온',
      unit: '°C',
      base: 36.7,
      amp: 0.6,
      noise: 0.18,
      minClamp: 35.5,
      maxClamp: 39.5,
      yMin: 35,
      yMax: 40,
      lineColor: const Color(0xFFEF4444), 
      dotColor: const Color(0xFFB91C1C),
    );

    final roomTempSeries = _ChartSeries.dummy(
      seed: patientId.hashCode ^ 0xBEEF,
      title: '병실온도',
      unit: '°C',
      base: 24.0,
      amp: 2.2,
      noise: 0.6,
      minClamp: 18,
      maxClamp: 30,
      yMin: 16,
      yMax: 32,
      lineColor: const Color(0xFF06B6D4),
      dotColor: const Color(0xFF0284C7),
    );

    final humiditySeries = _ChartSeries.dummy(
      seed: patientId.hashCode ^ 0xC0FFEE,
      title: '습도',
      unit: '%',
      base: 48.0,
      amp: 18.0,
      noise: 3.2,
      minClamp: 20,
      maxClamp: 85,
      yMin: 0,
      yMax: 100,
      lineColor: const Color(0xFF3B82F6),
      dotColor: const Color(0xFF1D4ED8),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
                                                        side: const BorderSide(color: Color(0xFFE5E7EB), width: 1)),
                          backgroundColor: const Color(0xFFFAFAFA),
                          title: const Text('정말 퇴원하겠습니까?', style: TextStyle(fontWeight: FontWeight.w900)),
                          content: Text(
                            '${p.name} 환자를 퇴원 처리하면 목록에서 제거됩니다.',
                            style: const TextStyle( fontWeight: FontWeight.w900,height: 1.4,color: Color(0xFF111827)),

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

                      // ✅ 상세창 닫기
                      if (context.mounted) Navigator.pop(context);
                    },
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
                    onPressed: () async {
                      await showDialog(
                        context: context,
                        builder: (_) => PatientEditDialog(patient: p),
                      );
                    },
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
                            value: '${v.bodytemp.toStringAsFixed(1)}°C',
                            icon: Icons.thermostat_outlined,
                            iconColor: const Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _VitalMiniCard(
                            title: '병실온도',
                            value: '${v.roomtemp.toStringAsFixed(1)} °C',
                            icon: Icons.thermostat_outlined,
                            iconColor: const Color(0xFFDC2626),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _VitalMiniCard(
                            title: '습도',
                            value: '${v.humidity.toStringAsFixed(0)}%',
                            icon: Icons.water_drop_outlined,
                            iconColor: const Color(0xFF0EA5E9),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _VitalMiniCard(
                            title: '움직임',
                            value: '${v.movement.label} ',
                            icon: Icons.accessibility_new_outlined,
                            iconColor: const Color(0xFF7C3AED),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ✅ 그래프 영역 (3개로 축소 + 스크린샷 느낌 라인차트 + 눌러서 확대)
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
      onTap: onOpenFull, // ✅ 그래프 카드 눌러서 확대
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
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ),
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
// ✅ 차트 구현(패키지 없이)
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

  /// 축(화면 통일감 위해 고정값도 가능)
  final double yMin;
  final double yMax;

  final Color lineColor;
  final Color dotColor;
  final Color selectedDotColor;
//컬러들

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

  static _ChartSeries dummy({
    required int seed,
    required String title,
    required String unit,
    required double base,
    required double amp,
    required double noise,
    required double minClamp,
    required double maxClamp,
    required double yMin,
    required double yMax,
    int count = 30,
    required Color lineColor,
    Color? dotColor,
    Color selectedDotColor = const Color(0xFF34D399),


  }) {
    final r = Random(seed);
    final now = DateTime.now();
    final pts = <_ChartPoint>[];

    // 최근 count개(1시간 간격)
    for (int i = 0; i < count; i++) {
      final t = now.subtract(Duration(hours: (count - 1) - i));
      final wave = sin(i / 4.0) * amp;
      final n = (r.nextDouble() * 2 - 1) * noise;
      var v = base + wave + n;
      v = v.clamp(minClamp, maxClamp).toDouble();
      pts.add(_ChartPoint(t, v));
    }

    return _ChartSeries(
      title: title,
      unit: unit,
      points: pts,
      yMin: yMin,
      yMax: yMax,

      lineColor: lineColor,
      dotColor: dotColor ?? lineColor,
      selectedDotColor: selectedDotColor,


    );
  }
}

/// 카드 안(작은) 차트: 정적 표시(라인+도트+그리드)
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
          painter: _LineChartPainter(
            series: series,
            selectedIndex: null,
            showTooltip: false,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// 전체화면(확대) 차트: 탭/드래그로 포인트 선택 + 툴팁
class _InteractiveLineChart extends StatefulWidget {
  final _ChartSeries series;
  const _InteractiveLineChart({required this.series});

  @override
  State<_InteractiveLineChart> createState() => _InteractiveLineChartState();
}

class _InteractiveLineChartState extends State<_InteractiveLineChart> {
  int? selected;

  void _pick(Offset localPos, Size size) {
    // painter와 동일 패딩
    const leftPad = 46.0;
    const rightPad = 16.0;
    final plotW = max(1.0, size.width - leftPad - rightPad);

    final n = widget.series.points.length;
    if (n <= 1) return;

    // x → index 근사(균등 간격 가정)
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
                painter: _LineChartPainter(
                  series: widget.series,
                  selectedIndex: selected,
                  showTooltip: true,
                ),
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
    // const line = Color(0xFF60A5FA); // 스크린샷 느낌의 블루 라인
    // const dot = Color(0xFF111827);
    const selectedDot = Color(0xFF34D399); // 선택 포인트(그린)
    const tooltipBg = Color(0xCC111827);

    // 배경
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    canvas.drawRRect(rrect, Paint()..color = bg);
    canvas.drawRRect(rrect, Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);

    // 패딩/플롯 영역
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

    // 그리드(가로 5줄)
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;

    const gridCount = 5;
    for (int i = 0; i <= gridCount; i++) {
      final y = plot.top + plot.height * (i / gridCount);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
    }

    // y 라벨(최소/중간/최대)
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i <= 2; i++) {
      final t = i / 2.0;
      final yVal = series.yMax + (series.yMin - series.yMax) * t; // 위가 max
      final y = plot.top + plot.height * t;
      tp.text = TextSpan(
        text: _fmtNum(yVal),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: axisText),
      );
      tp.layout(maxWidth: leftPad - 6);
      tp.paint(canvas, Offset(6, y - tp.height / 2));
    }

    // x 라벨(간단히 01~ 표시 느낌)
    final n = series.points.length;
    if (n >= 2) {
      final step = max(1, (n / 10).round()); // 대략 10개 내외
      for (int i = 0; i < n; i += step) {
        final x = plot.left + plot.width * (i / (n - 1));
        final d = series.points[i].t;
        final label = d.day.toString().padLeft(2, '0');
        tp.text = TextSpan(
          text: label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: axisText),
        );
        tp.layout();
        tp.paint(canvas, Offset(x - tp.width / 2, plot.bottom + 6));
      }
    }

    // 값 -> 좌표
    Offset ptToXY(int i) {
      final v = series.points[i].v;
      final t = i / (n - 1);
      final x = plot.left + plot.width * t;

      final yn = ((v - series.yMin) / (series.yMax - series.yMin)).clamp(0.0, 1.0);
      final y = plot.bottom - plot.height * yn;
      return Offset(x, y);
    }

    // 라인 경로(부드럽게: 간단한 quadratic smoothing)
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

    // 라인 그리기
    canvas.drawPath(
      path,
      Paint()
        ..color = series.lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // 도트
    for (int i = 0; i < n; i++) {
      final p = ptToXY(i);
      final isSel = selectedIndex == i;
      canvas.drawCircle(
        p,
        isSel ? 6 : 4.2,
        Paint()..color = series.dotColor,
      );
      // 흰색 테두리(스크린샷 느낌)
      canvas.drawCircle(
        p,
        isSel ? 6 : 4.2,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // 툴팁
    if (showTooltip && selectedIndex != null && selectedIndex! >= 0 && selectedIndex! < n) {
      final idx = selectedIndex!;
      final p = ptToXY(idx);
      final t = series.points[idx].t;
      final v = series.points[idx].v;

      final line1 = _fmtDateTime(t);
      final line2 = '${series.title}:${_fmtNum(v)}${series.unit}';//클릭 했을떄 뜨는 벨류 이름

      final textStyle = const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800);
      final tp1 = TextPainter(textDirection: TextDirection.ltr)
        ..text = TextSpan(text: line1, style: textStyle)
        ..layout();
      final tp2 = TextPainter(textDirection: TextDirection.ltr)
        ..text = TextSpan(text: line2, style: textStyle)
        ..layout();

      final w = max(tp1.width, tp2.width) + 18;
      final h = tp1.height + tp2.height + 14;

      // 포인트 위/오른쪽에 배치(넘치면 반대로)
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
              SizedBox(
                height: 520,
                child: _InteractiveLineChart(series: series),
              ),
              const SizedBox(height: 10),
              Text(
                '점을 터치 하면 상세 정보가 표시됩니다.',
                style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ===== helpers =====

String _fmtNum(double v) {
  // 정수면 0자리, 아니면 1자리
  if ((v - v.roundToDouble()).abs() < 1e-9) return v.round().toString();
  return v.toStringAsFixed(1);
}

String _fmt2(int n) => n.toString().padLeft(2, '0');

String _fmtDateTime(DateTime t) {
  // "2013-01-21 16:00:00" 형태
  return '${t.year}-${_fmt2(t.month)}-${_fmt2(t.day)} ${_fmt2(t.hour)}:${_fmt2(t.minute)}:${_fmt2(t.second)}';
}
