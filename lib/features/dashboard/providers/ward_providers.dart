import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/mock/mock_repository.dart';
import '../../../domain/models/patient.dart';
import '../../../domain/models/room.dart';
import '../../../domain/models/patient_realtime.dart';
import '../../../domain/models/ward.dart'; // ✅ 병동 모델

// ✅ (추가) 병동 목록/추가를 백엔드 연동형으로 만들기 위한 Repository
// - 아래 import 경로는 마스터님 프로젝트 실제 위치에 맞게 조정하세요.
import '../../../data/ward_repository.dart';
import '../../../data/mock/mock_ward_repository.dart';

/// =============================================================
/// 0) 병동(ward) 선택 상태 + 병동 목록/추가(버튼 기능용) Provider
/// =============================================================

/// ✅ 현재 선택된 병동(병동 선택 화면에서 탭하면 여기에 저장)
final selectedWardProvider = StateProvider<Ward?>((ref) => null);

/// ✅ (추가) 로그인/설정 등에서 병원 코드(hospitalCode)를 세팅해둘 곳
/// - 지금은 기본 1로 둠
/// - 백엔드 붙이면 로그인 응답에서 hospitalCode 내려오면 여기 state 세팅하면 됩니다.
final hospitalCodeProvider = StateProvider<int>((ref) => 1);

/// ✅ (추가) 병동 API/Mock 레포지토리
/// - 나중에 DioWardRepository로 갈아끼우면 UI/Provider는 그대로 사용 가능
final wardRepositoryProvider = Provider<WardRepository>((ref) {
  return MockWardRepository();
});

/// ✅ (추가) 병동 목록 로드 + 병동 추가까지 담당하는 Notifier(Family: hospitalCode별)
class WardListNotifier extends AutoDisposeFamilyAsyncNotifier<List<Ward>, int> {
  @override
  Future<List<Ward>> build(int hospitalCode) async {
    final repo = ref.read(wardRepositoryProvider);
    return repo.fetchWards(hospitalCode: hospitalCode);
  }

  /// ✅ (추가) 병동 추가 (병동 선택 페이지의 "추가 버튼"이 호출)
  /// - 백엔드 붙이면 Repository 내부에서 POST로 바뀌고, 여기 코드는 그대로 둬도 됩니다.
  Future<void> addWard({
    required int hospitalCode,
    required String categoryName,
    int? sortOrder,
  }) async {
    final repo = ref.read(wardRepositoryProvider);

    // 간단 검증
    final name = categoryName.trim();
    if (name.isEmpty) throw ArgumentError('병동 이름이 비어있습니다.');

    // 생성
    await repo.createWard(
      hospitalCode: hospitalCode,
      categoryName: name,
      sortOrder: sortOrder,
    );

    // 목록 새로고침(동기화 안정적)
    state = const AsyncLoading();
    state = AsyncData(await repo.fetchWards(hospitalCode: hospitalCode));
  }

  /// ✅ 수동 새로고침
  Future<void> refresh(int hospitalCode) async {
    final repo = ref.read(wardRepositoryProvider);
    state = const AsyncLoading();
    state = AsyncData(await repo.fetchWards(hospitalCode: hospitalCode));
  }
}

/// ✅ (추가) 병동 리스트 Provider (UI에서는 wardListProvider(hospitalCode) 형태로 watch)
final wardListProvider =
AutoDisposeAsyncNotifierProviderFamily<WardListNotifier, List<Ward>, int>(
  WardListNotifier.new,
);

/// =============================================================
/// 1) 환자별 "실시간 우선" 위험도 값 계산
/// =============================================================
/// - Patient.status 보다 realtimeProvider에 값이 있으면 realtime.status를 우선 사용
RiskStatus effectiveStatus(Ref ref, Patient p) {
  final rt = ref.watch(realtimeProvider)[p.id];
  return rt?.status ?? p.status;
}

/// =============================================================
/// 2) MockRepository (기존 더미 데이터 소스)
/// =============================================================
final repoProvider = Provider<MockRepository>((ref) => MockRepository());

/// =============================================================
/// 3) 층/호실 관련 Provider (현재는 병동과 무관하게 MockRepository 기준)
/// =============================================================
/// ⚠️ 나중에 병동별 층/호실이 달라진다면:
/// - floorsProvider/roomsProvider를 selectedWardProvider 또는 hospitalCode에 따라
///   repo 호출이 달라지도록 변경하면 됩니다.

final floorsProvider = Provider<List<int>>((ref) => ref.watch(repoProvider).floors());

final selectedFloorProvider = StateProvider<int>((ref) {
  final floors = ref.watch(floorsProvider);
  return floors.first;
});

final roomsProvider = Provider<List<Room>>((ref) {
  final floor = ref.watch(selectedFloorProvider);
  return ref.watch(repoProvider).roomsByFloor(floor);
});

/// =============================================================
/// 4) 환자 목록 StateNotifier (추가/수정/삭제)
/// =============================================================
class PatientNotifier extends StateNotifier<List<Patient>> {
  PatientNotifier(List<Patient> initial) : super(initial);

  void add(Patient p) => state = [...state, p];

  void update(Patient updated) {
    state = [
      for (final p in state) if (p.id == updated.id) updated else p,
    ];
  }

  void remove(String id) {
    state = state.where((p) => p.id != id).toList();
  }
}

final patientListProvider = StateNotifierProvider<PatientNotifier, List<Patient>>((ref) {
  final initial = ref.watch(repoProvider).initialPatients();
  return PatientNotifier(initial);
});

/// =============================================================
/// 5) 환자 필터 탭(전체/위험/주의/안정) + 선택 환자
/// =============================================================
enum PatientTab { all, danger, warning, stable }

final patientTabProvider = StateProvider<PatientTab>((ref) => PatientTab.all);
final selectedPatientIdProvider = StateProvider<String?>((ref) => null);

/// =============================================================
/// 6) 선택된 층에 속한 환자 목록
/// =============================================================
final patientsInSelectedFloorProvider = Provider<List<Patient>>((ref) {
  final floor = ref.watch(selectedFloorProvider);
  final all = ref.watch(patientListProvider);
  return all.where((p) => p.floor == floor).toList();
});

/// =============================================================
/// 7) 사이드패널 표시 환자 목록(탭 필터 적용 + 정렬)
/// =============================================================
/// - 탭 필터: all/danger/warning/stable
/// - 정렬: 위험 우선 + 호실/침대 순
final sidePanelPatientsProvider = Provider<List<Patient>>((ref) {
  final tab = ref.watch(patientTabProvider);
  final list = ref.watch(patientsInSelectedFloorProvider);

  Iterable<Patient> filtered = list;

  filtered = filtered.where((p) {
    final s = effectiveStatus(ref, p);
    switch (tab) {
      case PatientTab.all:
        return true;
      case PatientTab.danger:
        return s == RiskStatus.danger;
      case PatientTab.warning:
        return s == RiskStatus.warning;
      case PatientTab.stable:
        return s == RiskStatus.stable;
    }
  });

  final result = filtered.toList();

  // ✅ 위험 우선 + 호실/침대 순 (realtime 우선)
  result.sort((a, b) {
    final sa = effectiveStatus(ref, a);
    final sb = effectiveStatus(ref, b);

    final sp = statusPriority(sa).compareTo(statusPriority(sb));
    if (sp != 0) return sp;

    final rn = a.roomNo.compareTo(b.roomNo);
    if (rn != 0) return rn;

    return a.bedNo.compareTo(b.bedNo);
  });

  return result;
});

/// =============================================================
/// 8) 요약 카운트(전체/위험/주의/안정)
/// =============================================================
final summaryCountsProvider = Provider<(int total, int danger, int warning, int stable)>((ref) {
  final list = ref.watch(patientsInSelectedFloorProvider);

  int danger = 0;
  int warning = 0;
  int stable = 0;

  for (final p in list) {
    final s = effectiveStatus(ref, p);
    if (s == RiskStatus.danger) danger++;
    else if (s == RiskStatus.warning) warning++;
    else stable++;
  }

  return (list.length, danger, warning, stable);
});

/// =============================================================
/// 9) 호실별 환자 그룹핑
/// =============================================================
final patientsByRoomProvider = Provider<Map<int, List<Patient>>>((ref) {
  final list = ref.watch(patientsInSelectedFloorProvider);
  final map = <int, List<Patient>>{};
  for (final p in list) {
    map.putIfAbsent(p.roomNo, () => []).add(p);
  }
  return map;
});

/// =============================================================
/// 10) 호실-침대별 환자 맵(빠른 lookup용)
/// =============================================================
final patientByRoomBedProvider = Provider<Map<int, Map<int, Patient>>>((ref) {
  final list = ref.watch(patientsInSelectedFloorProvider);
  final map = <int, Map<int, Patient>>{};
  for (final p in list) {
    map.putIfAbsent(p.roomNo, () => {})[p.bedNo] = p;
  }
  return map;
});

/// =============================================================
/// 11) 실시간 데이터 Provider (patientId -> realtime)
/// =============================================================
/// - 나중에 하드웨어 이벤트(JSON) 수신 시 applyHardwareUpdate로 주입하면 됨
class RealtimeNotifier extends StateNotifier<Map<String, PatientRealtime>> {
  RealtimeNotifier() : super(const {});

  void upsert(String patientId, PatientRealtime rt) {
    state = {...state, patientId: rt};
  }

  void remove(String patientId) {
    final next = {...state};
    next.remove(patientId);
    state = next;
  }

  // ✅ 나중에 하드웨어 이벤트(JSON) 받으면 여기로 꽂으면 됨
  void applyHardwareUpdate({
    required String patientId,
    required RiskStatus status,
    required int alarmCount,
    DateTime? updatedAt,
  }) {
    upsert(
      patientId,
      PatientRealtime(
        status: status,
        updatedAt: updatedAt ?? DateTime.now(),
      ),
    );
  }
}

final realtimeProvider =
StateNotifierProvider<RealtimeNotifier, Map<String, PatientRealtime>>(
      (ref) => RealtimeNotifier(),
);

/// =============================================================
/// 12) 움직임 상태(욕창 앱 핵심 지표)
/// =============================================================
enum MovementStatus {
  stable,      // 안정
  caution,     // 주의
  reposition,  // 체위변경필요
}

extension MovementStatusLabel on MovementStatus {
  String get label => switch (this) {
    MovementStatus.stable => '안정',
    MovementStatus.caution => '주의',
    MovementStatus.reposition => '체위변경필요',
  };
}

/// =============================================================
/// 13) 실시간 바이탈 사인(체온/병실온도/습도/움직임) + Provider
/// =============================================================
class PatientVitals {
  final double bodytemp;
  final double roomtemp;
  final double humidity;
  final MovementStatus movement;

  const PatientVitals({
    required this.bodytemp,
    required this.roomtemp,
    required this.humidity,
    required this.movement,
  });

  // 프론트 더미
  static PatientVitals mock() => const PatientVitals(
    bodytemp: 37.2,
    roomtemp: 18.8,
    humidity: 45,
    movement: MovementStatus.stable,
  );

  PatientVitals copyWith({
    double? bodytemp,
    double? roomtemp,
    double? humidity,
    MovementStatus? movement,
  }) {
    return PatientVitals(
      bodytemp: bodytemp ?? this.bodytemp,
      roomtemp: roomtemp ?? this.roomtemp,
      humidity: humidity ?? this.humidity,
      movement: movement ?? this.movement,
    );
  }
}

class VitalsNotifier extends StateNotifier<Map<String, PatientVitals>> {
  VitalsNotifier() : super(const {});

  void upsert(String patientId, PatientVitals v) {
    state = {...state, patientId: v};
  }

  // 나중에 하드웨어에서 값 받을 때
  void applyHardwareVitals({
    required String patientId,
    double? bodytemp,
    double? roomtemp,
    double? humidity,
    MovementStatus? movement,
  }) {
    final cur = state[patientId] ?? PatientVitals.mock();
    upsert(
      patientId,
      cur.copyWith(
        bodytemp: bodytemp,
        roomtemp: roomtemp,
        humidity: humidity,
        movement: movement,
      ),
    );
  }
}

final vitalsProvider =
StateNotifierProvider<VitalsNotifier, Map<String, PatientVitals>>(
      (ref) => VitalsNotifier(),
);

/// =============================================================
/// ✅ (추가) 병동 추가 버튼에서 UI가 어떻게 쓰면 되는지(예시 주석)
/// =============================================================
/// 병동 선택 화면에서:
///
/// final hospitalCode = ref.watch(hospitalCodeProvider);
/// final wardsAsync = ref.watch(wardListProvider(hospitalCode));
///
/// IconButton(
///   icon: const Icon(Icons.add),
///   onPressed: () async {
///     final name = await showDialog로 병동명 입력받기;
///     if (name == null) return;
///
///     await ref.read(wardListProvider(hospitalCode).notifier).addWard(
///       hospitalCode: hospitalCode,
///       categoryName: name,
///     );
///   },
/// )
///
/// 그리고 병동을 탭하면:
/// ref.read(selectedWardProvider.notifier).state = ward;
/// =============================================================
