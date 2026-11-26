class AuditLogModel {
  final String id;
  final String adminId;
  final String adminName;
  final String action; // e.g., "Deleted Driver", "Updated Schedule"
  final String target; // e.g., "Driver: John Doe"
  final DateTime timestamp;
  final String? details;
  final String? ipAddress;

  AuditLogModel({
    required this.id,
    required this.adminId,
    required this.adminName,
    required this.action,
    required this.target,
    required this.timestamp,
    this.details,
    this.ipAddress,
  });

  factory AuditLogModel.fromMap(Map<String, dynamic> data, {String? id}) {
    DateTime ts;
    try {
      ts = data['timestamp'] != null
          ? (data['timestamp'] is DateTime
              ? data['timestamp'] as DateTime
              : DateTime.parse(data['timestamp'].toString()))
          : (data['created_at'] != null
              ? DateTime.parse(data['created_at'].toString())
              : DateTime.now());
    } catch (_) {
      ts = DateTime.now();
    }

    return AuditLogModel(
      id: id ?? data['id']?.toString() ?? '',
      adminId: data['adminId']?.toString() ?? data['admin_id']?.toString() ?? data['admin']?.toString() ?? '',
      adminName: data['adminName'] ?? data['admin_name'] ?? 'Unknown Admin',
      action: data['action'] ?? '',
      target: data['target'] ?? '',
      timestamp: ts,
      details: data['details'],
      ipAddress: data['ipAddress'] ?? data['ip_address'],
    );
  }

  // Backward compatibility factory
  factory AuditLogModel.fromFirestore(dynamic doc) {
    if (doc is Map<String, dynamic>) {
      return AuditLogModel.fromMap(doc);
    }
    // Handle mock or custom doc
    try {
      final map = doc.data() as Map<String, dynamic>;
      return AuditLogModel.fromMap(map, id: doc.id?.toString());
    } catch (_) {
      return AuditLogModel.fromMap({});
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'adminId': adminId,
      'adminName': adminName,
      'action': action,
      'target': target,
      'timestamp': timestamp.toIso8601String(),
      'details': details,
      'ipAddress': ipAddress,
    };
  }
}
