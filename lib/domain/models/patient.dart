enum RiskStatus { danger, warning, stable }

class Patient {
  final String id;

  // 기본정보
  final String name;
  final int age;
  final String gender;      // '남'/'여'/'기타'
  final DateTime birthDate; // 생년월일

  // 병실 배정
  final String ward; // 예: '7층 병동'
  final int floor;   // 예: 7
  final int roomNo;  // 예: 501
  final int bedNo;   // 예: 1~8

  // 진료정보
  final String diagnosis;      // 진단명 (필수)
  final String physician;      // 주치의 (필수)
  final String nurse;          // 담당 간호사
  final String allergy;        // 알레르기
  final String note;           // 특이사항

  // 상태 표시용
  final RiskStatus status;
  final int alarmCount;

  const Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.birthDate,
    required this.ward,
    required this.floor,
    required this.roomNo,
    required this.bedNo,
    required this.diagnosis,
    required this.physician,
    required this.nurse,
    required this.allergy,
    required this.note,
    required this.status,
    required this.alarmCount,
  });

  Patient copyWith({
    String? id,
    String? name,
    int? age,
    String? gender,
    DateTime? birthDate,
    String? ward,
    int? floor,
    int? roomNo,
    int? bedNo,
    String? diagnosis,
    String? physician,
    String? nurse,
    String? allergy,
    String? note,
    RiskStatus? status,
    int? alarmCount,
  }) {
    return Patient(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      ward: ward ?? this.ward,
      floor: floor ?? this.floor,
      roomNo: roomNo ?? this.roomNo,
      bedNo: bedNo ?? this.bedNo,
      diagnosis: diagnosis ?? this.diagnosis,
      physician: physician ?? this.physician,
      nurse: nurse ?? this.nurse,
      allergy: allergy ?? this.allergy,
      note: note ?? this.note,
      status: status ?? this.status,
      alarmCount: alarmCount ?? this.alarmCount,
    );
  }
}

String statusLabel(RiskStatus s) {
  switch (s) {
    case RiskStatus.danger:
      return '위험';
    case RiskStatus.warning:
      return '주의';
    case RiskStatus.stable:
      return '안정';
  }
}

int statusPriority(RiskStatus s) {
  switch (s) {
    case RiskStatus.danger:
      return 0;
    case RiskStatus.warning:
      return 1;
    case RiskStatus.stable:
      return 2;
  }
}
