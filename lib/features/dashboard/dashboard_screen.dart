import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'package:medicalapp/urlConfig.dart';
import 'package:medicalapp/storage_keys.dart';

import 'widgets/top_header.dart';
import 'widgets/summary_cards.dart';
import 'widgets/side_panel.dart';
import 'widgets/room_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState(
  );
}
class _DashboardScreenState extends State<DashboardScreen> {
  static const _storage = FlutterSecureStorage();
  final _scrollCtrl = ScrollController();

  late final String _front_url;
  Map<String, dynamic> data = {};

  bool _isLoading = true;

  String wardName = '전체';

  // ✅ (추가) TopHeader 층 드롭다운에 넣을 목록/로딩상태
  List<Map<String, dynamic>> floors = [];
  int? selectedFloorStCode; // 선택된 층의 hospital_st_code
  String selectedFloorLabel = ''; // 선택된 층의 category_name (예: "2층", "B1층")
  String floorLabel = '';

  bool floorsLoading = false;

  // TODO: rooms / counts는 기존 provider 로직을 옮기거나 API 나오면 여기서 채우면 됨
  int total = 0,
      danger = 0,
      warning = 0,
      stable = 0;
  List rooms = const [];

  @override
  void initState() {
    super.initState();
    _front_url = Urlconfig.serverUrl.toString();
    loadData();
  }

  Future<void> loadData() async {
    setState(() => _isLoading = true);
    await getData();
    setState(() => _isLoading = false);
  }

  //데이터 셋업
  Future<void> getData() async {
    // 1) 로그인 화면에서 저장해 둔 병동명/코드 읽기
    final savedWardName = await _storage.read(
        key: StorageKeys.selectedWardName);
    final savedWardStCodeStr = await _storage.read(
        key: StorageKeys.selectedWardStCode);

    wardName = (savedWardName == null || savedWardName
        .trim()
        .isEmpty) ? '전체' : savedWardName.trim();
    final wardStCode = int.tryParse((savedWardStCodeStr ?? '').trim());
    debugPrint(
        'savedWardName=$savedWardName, savedWardStCode=$savedWardStCodeStr');

    // 병동 코드가 없으면 층 드롭다운 자체를 비워둠(예외 UI 없이)
    if (wardStCode == null) {
      floors = [];
      selectedFloorStCode = null;
      selectedFloorLabel = '';
      return;
    }


    // 2) ✅ 병동별 층 조회
    try {
      floorsLoading = true;

      final uri = Uri.parse(
          '$_front_url/api/hospital/structure/floor?hospital_st_code=$wardStCode');
      final res = await http.get(
          uri, headers: {'Content-Type': 'application/json'});

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return;
      if (decoded['code'] != 1) return;

      final body = decoded['data'] as Map<String, dynamic>;

      final listAny = (body['floors'] as List?) ?? [];
      floors = listAny.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      if (floors.isEmpty) {
        selectedFloorStCode = null;
        floorLabel = '';
        return;
      }

      // ✅ 기본 선택: sort_order가 가장 작은 것(없으면 첫 번째)
      floors.sort((a, b) {
        final sa = int.tryParse(a['sort_order']?.toString() ?? '') ?? 999999;
        final sb = int.tryParse(b['sort_order']?.toString() ?? '') ?? 999999;
        return sa.compareTo(sb);
      });

      final first = floors.first;
      selectedFloorStCode =
          int.tryParse(first['hospital_st_code']?.toString() ?? '');
      floorLabel = first['category_name']?.toString() ?? '';

      await _storage.write(key: StorageKeys.selectedFloorStCode,
          value: (selectedFloorStCode ?? '').toString());
      await _storage.write(key: StorageKeys.floorLabel, value: floorLabel);
    } catch (_) {
      floors = [];
      selectedFloorStCode = null;
      floorLabel = '';
    } finally {
      floorsLoading = false;
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF3F4F6),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Row(
          children: [
            _buildSidePanel(),
            Expanded(
              child: Column(
                children: [
                  _buildTopHeader(),
                  Expanded(
                    child: _buildMainScroll(
                      wardName: wardName,
                      floorLabel: floorLabel,
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
    return SidePanel(
      key: ValueKey('side-${selectedFloorStCode ?? 'none'}'),
      floorStCode: selectedFloorStCode,
    );
  }


  //상단 타이틀
  Widget _buildTopHeader() {
    return TopHeader(
      floors: floors,
      selectedFloorStCode: selectedFloorStCode,
      floorLabel: floorLabel,
      loadingFloors: floorsLoading,
      onFloorChanged: (nextStCode) async {
        // 선택된 floor 찾기
        Map<String, dynamic>? picked;
        for (final f in floors) {
          final st = int.tryParse(f['hospital_st_code']?.toString() ?? '');
          if (st == nextStCode) {
            picked = f;
            break;
          }
        }
        if (picked == null) return;

        setState(() {
          selectedFloorStCode = nextStCode;
          floorLabel = picked!['category_name']?.toString() ?? '';
        });

        await _storage.write(
            key: StorageKeys.selectedFloorStCode, value: nextStCode.toString());
        await _storage.write(
            key: StorageKeys.floorLabel, value: floorLabel);

        // TODO: 여기서 “층 변경 시 rooms/summary 재조회” 붙이면 됨
        // await loadData();
      },
    );
  }




  Widget _buildMainScroll({
    required String wardName,
    required String floorLabel,
    required int total,
    required int danger,
    required int warning,
    required int stable,
    required List rooms,
  }) {
    return Scrollbar(
      controller: _scrollCtrl,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCards(
                total: total, danger: danger, warning: warning, stable: stable),
            const SizedBox(height: 18),
            _buildWardTitle(wardName: wardName, floorLabel: floorLabel),
            const SizedBox(height: 10),
            RoomsSection(floorStCode: selectedFloorStCode),
          ],
        ),
      ),
    );
  }

//위험,주의,경고,카드
  Widget _buildSummaryCards({
    required int total,
    required int danger,
    required int warning,
    required int stable,
  }) {
    return SummaryCards(floorStCode: selectedFloorStCode);
  }

  // 룸 그리드
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

  //타이틀
  Widget _buildWardTitle(
      {required String wardName, required String floorLabel}) {
    final floorText = floorLabel
        .trim()
        .isEmpty ? '층 정보 없음' : floorLabel.trim();

    return Text(
      '$floorText 병동',
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
    );
  }
}
