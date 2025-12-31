import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/ward_providers.dart';
import 'widgets/top_header.dart';
import 'widgets/summary_cards.dart';
import 'widgets/side_panel.dart';
import 'widgets/room_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ 로그인(병동 선택)에서 세팅되는 값
    final ward = ref.watch(selectedWardProvider);

    // 병동 선택이 안 된 상태(웹 새로고침/직접 진입 등) 방어
    if (ward == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        body: Center(
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: const [
                BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('병동이 선택되지 않았습니다.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('로그인 후 병동을 선택해 주세요.',
                    style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF65C466),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  onPressed: () => context.go('/login'),
                  child: const Text('로그인으로 이동'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 기존 로직 유지
    final (total, danger, warning, stable) = ref.watch(summaryCountsProvider);
    final floor = ref.watch(selectedFloorProvider);
    final rooms = ref.watch(roomsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Row(
          children: [
            // 좌측 패널(독립 스크롤)
            const SidePanel(),

            // 우측 메인(독립 스크롤)
            Expanded(
              child: Column(
                children: [
                  const TopHeader(),

                  Expanded(
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SummaryCards(total: total, danger: danger, warning: warning, stable: stable),
                            const SizedBox(height: 18),

                            // ✅ 병동명 + 층 표시
                            Text(
                              '${ward.categoryName} · ${floor}층 병동',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 10),

                            // 호실 카드들(2열)
                            LayoutBuilder(
                              builder: (context, c) {
                                final twoCol = c.maxWidth >= 1200;
                                final itemW = twoCol ? (c.maxWidth - 20) / 2 : c.maxWidth;

                                return Wrap(
                                  spacing: 20,
                                  runSpacing: 20,
                                  children: [
                                    for (final r in rooms)
                                      SizedBox(
                                        width: itemW,
                                        child: RoomCard(room: r),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
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
