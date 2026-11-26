class StudentModel {
  final String id;
  final String name;
  final String email;
  final String studentId; // Roll Number
  final String regNo;
  final String department;
  final String semester;
  final String phoneNumber;
  final String profileImage;
  final String status; // 'Active', 'Inactive', 'Online', 'Offline'
  final bool isVerified;
  final bool isBlocked;
  final DateTime createdAt;

  StudentModel({
    required this.id,
    required this.name,
    required this.email,
    required this.studentId,
    required this.regNo,
    required this.department,
    required this.semester,
    required this.phoneNumber,
    required this.profileImage,
    this.status = 'Offline',
    this.isVerified = true,
    this.isBlocked = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': id,
      'name': name,
      'email': email,
      'studentId': studentId,
      'rollNo': studentId,
      'regNo': regNo,
      'department': department,
      'semester': semester,
      'phoneNumber': phoneNumber,
      'phone': phoneNumber,
      'role': 'student',
      'profileImage': profileImage,
      'status': status,
      'isVerified': isVerified,
      'isBlocked': isBlocked,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory StudentModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime parsedCreatedAt;
    try {
      if (map['createdAt'] != null) {
        parsedCreatedAt = map['createdAt'] is DateTime
            ? map['createdAt'] as DateTime
            : DateTime.parse(map['createdAt'].toString());
      } else if (map['created_at'] != null) {
        parsedCreatedAt = DateTime.parse(map['created_at'].toString());
      } else {
        parsedCreatedAt = DateTime.now();
      }
    } catch (_) {
      parsedCreatedAt = DateTime.now();
    }

    final profile = map['student_profile'] as Map<String, dynamic>? ?? {};

    return StudentModel(
      id: (map['id'] ?? map['uid'] ?? docId ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      studentId: (map['studentId'] ?? map['rollNo'] ?? profile['roll_no'] ?? 'N/A').toString(),
      regNo: (map['regNo'] ?? profile['registration_no'] ?? 'N/A').toString(),
      department: (map['department'] ?? profile['department'] ?? 'N/A').toString(),
      semester: (map['semester'] ?? profile['semester']?.toString() ?? 'N/A').toString(),
      phoneNumber: (map['phoneNumber'] ?? map['phone'] ?? 'N/A').toString(),
      profileImage: (map['profileImage'] ?? map['profileImageUrl'] ?? map['profile_image'] ?? '').toString(),
      status: (map['status'] ?? (map['is_verified'] == true ? 'Active' : 'Offline')).toString(),
      isVerified: map['isVerified'] ?? map['is_verified'] ?? true,
      isBlocked: map['isBlocked'] ?? map['is_blocked'] ?? false,
      createdAt: parsedCreatedAt,
    );
  }

  StudentModel copyWith({
    String? id,
    String? name,
    String? email,
    String? studentId,
    String? regNo,
    String? department,
    String? semester,
    String? phoneNumber,
    String? profileImage,
    String? status,
    bool? isVerified,
    bool? isBlocked,
    DateTime? createdAt,
  }) {
    return StudentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      studentId: studentId ?? this.studentId,
      regNo: regNo ?? this.regNo,
      department: department ?? this.department,
      semester: semester ?? this.semester,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImage: profileImage ?? this.profileImage,
      status: status ?? this.status,
      isVerified: isVerified ?? this.isVerified,
      isBlocked: isBlocked ?? this.isBlocked,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
