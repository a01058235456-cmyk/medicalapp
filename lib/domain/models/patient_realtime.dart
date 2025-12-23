import 'patient.dart';

class PatientRealtime {
  final RiskStatus status;
  final int alarmCount;
  final DateTime updatedAt;

  const PatientRealtime({
    required this.status,
    required this.alarmCount,
    required this.updatedAt,
  });

  PatientRealtime copyWith({
    RiskStatus? status,
    int? alarmCount,
    DateTime? updatedAt,
  }) {
    return PatientRealtime(
      status: status ?? this.status,
      alarmCount: alarmCount ?? this.alarmCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
