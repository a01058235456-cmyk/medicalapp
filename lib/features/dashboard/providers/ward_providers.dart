import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/mock/mock_repository.dart';
import '../../../domain/models/patient.dart';
import '../../../domain/models/room.dart';
import '../../../domain/models/patient_realtime.dart';

//환자별 실시간 우선 값
RiskStatus effectiveStatus(Ref ref, Patient p) {
  final rt = ref.watch(realtimeProvider)[p.id];
  return rt?.status ?? p.status;
}

int effectiveAlarmCount(Ref ref, Patient p) {
  final rt = ref.watch(realtimeProvider)[p.id];
  return rt?.alarmCount ?? p.alarmCount;
}


final repoProvider = Provider<MockRepository>((ref) => MockRepository());

final floorsProvider = Provider<List<int>>((ref) => ref.watch(repoProvider).floors());

final selectedFloorProvider = StateProvider<int>((ref) {
  final floors = ref.watch(floorsProvider);
  return floors.first;
});

final roomsProvider = Provider<List<Room>>((ref) {
  final floor = ref.watch(selectedFloorProvider);
  return ref.watch(repoProvider).roomsByFloor(floor);
});

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

enum PatientTab { all, danger, warning, stable }

final patientTabProvider = StateProvider<PatientTab>((ref) => PatientTab.all);

final selectedPatientIdProvider = StateProvider<String?>((ref) => null);

final patientsInSelectedFloorProvider = Provider<List<Patient>>((ref) {
  final floor = ref.watch(selectedFloorProvider);
  final all = ref.watch(patientListProvider);
  return all.where((p) => p.floor == floor).toList();
});

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
  // ✅ 위험 우선 + 알람 많은 순 + 호실/침대 순 (realtime 우선)
  result.sort((a, b) {
    final sa = effectiveStatus(ref, a);
    final sb = effectiveStatus(ref, b);

    final sp = statusPriority(sa).compareTo(statusPriority(sb));
    if (sp != 0) return sp;

    final aca = effectiveAlarmCount(ref, a);
    final acb = effectiveAlarmCount(ref, b);
    final ac = acb.compareTo(aca);
    if (ac != 0) return ac;

    final rn = a.roomNo.compareTo(b.roomNo);
    if (rn != 0) return rn;

    return a.bedNo.compareTo(b.bedNo);
  });

  return result;
});





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

final patientsByRoomProvider = Provider<Map<int, List<Patient>>>((ref) {
  final list = ref.watch(patientsInSelectedFloorProvider);
  final map = <int, List<Patient>>{};
  for (final p in list) {
    map.putIfAbsent(p.roomNo, () => []).add(p);
  }
  return map;
});

final patientByRoomBedProvider = Provider<Map<int, Map<int, Patient>>>((ref) {
  final list = ref.watch(patientsInSelectedFloorProvider);
  final map = <int, Map<int, Patient>>{};
  for (final p in list) {
    map.putIfAbsent(p.roomNo, () => {})[p.bedNo] = p;
  }
  return map;
});















// patientId -> realtime
//싷시간 데이터 주ㄴ고 받는 곳
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
        alarmCount: alarmCount,
        updatedAt: updatedAt ?? DateTime.now(),
      ),
    );
  }
}

final realtimeProvider =
StateNotifierProvider<RealtimeNotifier, Map<String, PatientRealtime>>(
      (ref) => RealtimeNotifier(),
);



//움직임
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

//실시간 바이탈 사인
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

  PatientVitals copyWith({double? bodytemp, double? roomtemp, double? humidity, MovementStatus? movement}) {
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

final vitalsProvider = StateNotifierProvider<VitalsNotifier, Map<String, PatientVitals>>(
      (ref) => VitalsNotifier(),
);
