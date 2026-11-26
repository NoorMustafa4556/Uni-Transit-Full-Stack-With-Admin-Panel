class TransportContactModel {
  final int id;
  final String title;
  final String phone;
  final String? email;
  final String? role;
  final bool isEmergency;
  final int displayOrder;

  TransportContactModel({
    required this.id,
    required this.title,
    required this.phone,
    this.email,
    this.role,
    this.isEmergency = false,
    this.displayOrder = 0,
  });

  factory TransportContactModel.fromMap(Map<String, dynamic> map) {
    return TransportContactModel(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
      title: map['title'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'],
      role: map['role'],
      isEmergency: map['is_emergency'] ?? false,
      displayOrder: map['display_order'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'phone': phone,
      'email': email,
      'role': role,
      'is_emergency': isEmergency,
      'display_order': displayOrder,
    };
  }
}
