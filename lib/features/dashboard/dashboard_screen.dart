import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/ward_providers.dart';
import 'widgets/top_header.dart';
import 'widgets/summary_cards.dart';
import 'widgets/side_panel.dart';
import 'widgets/room_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

                            Text('${floor}층 병동', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
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
