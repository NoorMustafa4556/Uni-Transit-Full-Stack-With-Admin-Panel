class ChangeRequestModel {
  final int id;
  final int requestedById;
  final String requestedByName;
  final String entityType;
  final String entityId;
  final String action;
  final Map<String, dynamic> payload;
  final String status; // 'pending_approval', 'approved', 'rejected'
  final int? reviewedById;
  final String? reviewedByName;
  final String? reviewNote;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  ChangeRequestModel({
    required this.id,
    required this.requestedById,
    required this.requestedByName,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.payload,
    required this.status,
    this.reviewedById,
    this.reviewedByName,
    this.reviewNote,
    required this.createdAt,
    this.reviewedAt,
  });

  factory ChangeRequestModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    return ChangeRequestModel(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
      requestedById: map['requested_by'] is int ? map['requested_by'] : int.tryParse(map['requested_by']?.toString() ?? '0') ?? 0,
      requestedByName: map['requested_by_name'] ?? 'Sub-Admin',
      entityType: map['entity_type'] ?? '',
      entityId: map['entity_id']?.toString() ?? '',
      action: map['action'] ?? '',
      payload: map['payload_json'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(map['payload_json'])
          : (map['payload_json'] is Map ? Map<String, dynamic>.from(map['payload_json']) : {}),
      status: map['status'] ?? 'pending_approval',
      reviewedById: map['reviewed_by'] != null ? int.tryParse(map['reviewed_by'].toString()) : null,
      reviewedByName: map['reviewed_by_name'],
      reviewNote: map['review_note'],
      createdAt: parseDate(map['created_at']),
      reviewedAt: map['reviewed_at'] != null ? parseDate(map['reviewed_at']) : null,
    );
  }
}
