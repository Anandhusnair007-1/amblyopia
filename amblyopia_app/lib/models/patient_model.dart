class PatientModel {
  final String id;
  final String ageGroup;
  final String villageId;
  final DateTime createdAt;

  const PatientModel({
    required this.id,
    required this.ageGroup,
    required this.villageId,
    required this.createdAt,
  });

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      id: json['id']?.toString() ?? '',
      ageGroup: json['age_group']?.toString() ?? 'child',
      villageId: json['village_id']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'age_group': ageGroup,
        'village_id': villageId,
        'created_at': createdAt.toIso8601String(),
      };
}
