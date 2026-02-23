class SessionModel {
  final String id;
  final String patientId;
  final String villageId;
  final String ageGroup;
  final DateTime startedAt;
  DateTime? completedAt;
  bool synced;

  SessionModel({
    required this.id,
    required this.patientId,
    required this.villageId,
    required this.ageGroup,
    required this.startedAt,
    this.completedAt,
    this.synced = false,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id']?.toString() ?? '',
      patientId: json['patient_id']?.toString() ?? '',
      villageId: json['village_id']?.toString() ?? '',
      ageGroup: json['age_group']?.toString() ?? 'child',
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      synced: (json['synced'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patient_id': patientId,
        'village_id': villageId,
        'age_group': ageGroup,
        'started_at': startedAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'synced': synced ? 1 : 0,
      };
}
