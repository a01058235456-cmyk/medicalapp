import 'patient.dart';

class PatientRealtime {
  final RiskStatus status;
  final DateTime updatedAt;

  const PatientRealtime({
    required this.status,
    required this.updatedAt,
  });


  PatientRealtime copyWith({
    RiskStatus? status,
    int? alarmCount,
    DateTime? updatedAt,
  }) {
    return PatientRealtime(
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
