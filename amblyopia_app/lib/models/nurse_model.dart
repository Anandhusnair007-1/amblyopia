class NurseModel {
  final String id;
  final String name;
  final String phone;
  final String villageId;
  final String token;

  const NurseModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.villageId,
    required this.token,
  });

  factory NurseModel.fromJson(Map<String, dynamic> json) {
    return NurseModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone_number']?.toString() ?? '',
      villageId: json['village_id']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone_number': phone,
        'village_id': villageId,
        'token': token,
      };
}
