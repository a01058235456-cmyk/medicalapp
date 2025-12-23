import 'package:flutter/material.dart';

class SummaryCards extends StatelessWidget {
  final int total;
  final int danger;
  final int warning;
  final int stable;

  const SummaryCards({
    super.key,
    required this.total,
    required this.danger,
    required this.warning,
    required this.stable,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _Card(title: '총 환자 수', value: '${total}명', valueColor: const Color(0xFF111827))),
        const SizedBox(width: 25),
        Expanded(child: _Card(title: '위험 상태', value: '${danger}명', valueColor: const Color(0xFFEF4444))),
        const SizedBox(width: 25),
        Expanded(child: _Card(title: '주의 필요', value: '${warning}명', valueColor: const Color(0xFFF59E0B))),
        const SizedBox(width: 25),
        Expanded(child: _Card(title: '안정 상태', value: '${stable}명', valueColor: const Color(0xFF22C55E))),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String value;
  final Color valueColor;

  const _Card({required this.title, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: valueColor)),
        ],
      ),
    );
  }
}
