class SupportTicketModel {
  final String id;
  final String email;
  final String issue;
  final String name;
  final String phone;
  final String status;
  final DateTime timestamp;
  final String userEmail;
  final String userId;
  final String userName;
  final String userRole;
  final int? tripId;
  final String? adminReply;
  final bool userRead;
  final bool adminRead;

  SupportTicketModel({
    required this.id,
    required this.email,
    required this.issue,
    required this.name,
    required this.phone,
    required this.status,
    required this.timestamp,
    required this.userEmail,
    required this.userId,
    required this.userName,
    required this.userRole,
    this.tripId,
    this.adminReply,
    this.userRead = false,
    this.adminRead = false,
  });

  factory SupportTicketModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime ts;
    try {
      final raw = map['timestamp'] ?? map['created_at'];
      ts = raw != null ? DateTime.parse(raw.toString()) : DateTime.now();
    } catch (_) {
      ts = DateTime.now();
    }

    return SupportTicketModel(
      id: (id.isNotEmpty ? id : (map['id'] ?? '')).toString(),
      email: (map['email'] ?? map['userEmail'] ?? '').toString(),
      issue: (map['issue'] ?? 'No issue description provided').toString(),
      name: (map['name'] ?? map['userName'] ?? map['user_name'] ?? 'Anonymous').toString(),
      phone: (map['phone'] ?? 'No phone').toString(),
      status: (map['status'] ?? 'pending').toString(),
      timestamp: ts,
      userEmail: (map['userEmail'] ?? map['email'] ?? '').toString(),
      userId: (map['userId'] ?? map['user'] ?? '').toString(),
      userName: (map['userName'] ?? map['user_name'] ?? 'Anonymous').toString(),
      userRole: (map['userRole'] ?? map['user_role'] ?? 'Student').toString(),
      tripId: map['trip'] != null ? int.tryParse(map['trip'].toString()) : null,
      adminReply: map['adminReply'] ?? map['admin_reply'],
      userRead: map['userRead'] ?? map['user_read'] ?? false,
      adminRead: map['adminRead'] ?? map['admin_read'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'issue': issue,
      'name': name,
      'phone': phone,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
      'userEmail': userEmail,
      'userId': userId,
      'userName': userName,
      'userRole': userRole,
      'trip': tripId,
      'adminReply': adminReply,
      'userRead': userRead,
      'adminRead': adminRead,
    };
  }
}
