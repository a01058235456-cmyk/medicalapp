import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicalapp/config/app_config.dart';
import 'package:medicalapp/urlConfig.dart';
import 'providers/ward_providers.dart';
import 'widgets/top_header.dart';
import 'widgets/summary_cards.dart';
import 'widgets/side_panel.dart';
import 'widgets/room_card.dart';
import '../auth/providers/ward_select_providers.dart' as ws;






class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}



class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late final String _front_url;
  Map<String, dynamic> data = {};

  @override
  void initState() {
    super.initState();
    _front_url = Urlconfig.serverUrl.toString();
    loadData();
  }

  Future<void> loadData() async {
    await getData();
  }

  getData() async {












  }

  @override
  Widget build(BuildContext context) {
    final ward = ref.watch(selectedWardProvider);
    final (total, danger, warning, stable) = ref.watch(summaryCountsProvider);
    final floor = ref.watch(selectedFloorProvider);
    final rooms = ref.watch(roomsProvider);

    // ✅ 병동 null이어도 크래시 방지 (예외 UI 없음)
    final wardName = ward?.categoryName ?? '전체';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Row(
          children: [
            // 좌측 패널(독립 스크롤)
            _buildSidePanel(),
            // 우측 메인(독립 스크롤)
            Expanded(
              child: Column(
                children: [
                  _buildTopHeader(),
                  Expanded(
                    child: _buildMainScroll(
                      wardName: wardName,
                      floor: floor,
                      total: total,
                      danger: danger,
                      warning: warning,
                      stable: stable,
                      rooms: rooms,
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

  // ---------------- UI Builders ----------------

  Widget _buildSidePanel() {
    return const SidePanel();
  }

  Widget _buildTopHeader() {
    return const TopHeader();
  }

  //메인 스크롤//
  Widget _buildMainScroll({
    required String wardName,
    required int floor,
    required int total,
    required int danger,
    required int warning,
    required int stable,
    required List rooms,
  }) {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCards(total: total, danger: danger, warning: warning, stable: stable),
            const SizedBox(height: 18),
            _buildWardTitle(wardName: wardName, floor: floor),
            const SizedBox(height: 10),
            _buildRoomGrid(rooms: rooms),
          ],
        ),
      ),
    );
  }


 //메인 환자 카드
  Widget _buildSummaryCards({
    required int total,
    required int danger,
    required int warning,
    required int stable,
  }) {
    return SummaryCards(
      total: total,
      danger: danger,
      warning: warning,
      stable: stable,
    );
  }


  //병동 환자 카드 그리드 영역
  Widget _buildRoomGrid({required List rooms}) {
    return LayoutBuilder(
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
    );
  }



  //병동네임 ,층
  Widget _buildWardTitle({
    required String wardName,
    required int floor,
  }) {
    return Text( //data["hospital_name"]
      '${wardName} · ${floor}층 병동',
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
    );
  }
}
