/// Model representing a user profile from Django REST backend.
class UserModel {
  final String uid; // ID or email
  final int? id;
  final String name;
  final String email;
  final String role; // 'student', 'driver', 'sub_admin', 'super_admin'
  final String? phone;
  final String? rollNo;
  final String? regNo;
  final String? department;
  final String? semester;
  final String? profileImage;
  final bool isVerified;
  final bool isBlocked;
  final Map<String, dynamic>? defaultStop;

  UserModel({
    required this.uid,
    this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.rollNo,
    this.regNo,
    this.department,
    this.semester,
    this.profileImage,
    this.isVerified = true,
    this.isBlocked = false,
    this.defaultStop,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final rawId = map['id'];
    final uid = rawId != null ? rawId.toString() : (map['uid'] ?? map['email'] ?? '');
    
    // Normalized role string (e.g. Student, Driver, Admin)
    final rawRole = (map['role'] ?? 'student').toString().toLowerCase();
    String normalizedRole = 'Student';
    if (rawRole == 'driver') {
      normalizedRole = 'Driver';
    } else if (rawRole == 'sub_admin' || rawRole == 'super_admin' || rawRole == 'admin') {
      normalizedRole = 'Admin';
    }

    final studentProfile = map['student_profile'] as Map<String, dynamic>?;
    final driverProfile = map['driver_profile'] as Map<String, dynamic>?;

    return UserModel(
      uid: uid,
      id: rawId is int ? rawId : int.tryParse(rawId.toString()),
      name: map['name'] ?? 'User',
      email: map['email'] ?? '',
      role: normalizedRole,
      phone: map['phone'],
      rollNo: map['rollNo'] ?? map['roll_no'] ?? studentProfile?['roll_no'],
      regNo: map['regNo'] ?? map['reg_no'] ?? studentProfile?['reg_no'],
      department: map['department'] ?? studentProfile?['department'],
      semester: map['semester'] ?? studentProfile?['semester'],
      profileImage: map['profile_image'] ?? map['profileImage'] ?? map['profileImageUrl'],
      isVerified: map['is_verified'] ?? (driverProfile?['is_verified'] ?? true),
      isBlocked: map['is_blocked'] ?? false,
      defaultStop: map['default_stop'] ?? studentProfile?['default_stop'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'roll_no': rollNo,
      'reg_no': regNo,
      'department': department,
      'semester': semester,
      'profile_image': profileImage,
      'is_verified': isVerified,
      'is_blocked': isBlocked,
    };
  }

  bool get isStudent => role.toLowerCase() == 'student';
  bool get isDriver => role.toLowerCase() == 'driver';
  bool get isAdmin => role.toLowerCase() == 'admin' || role.toLowerCase().contains('admin');

  String? get displayName => name;

  bool get hasProfileImage => profileImage != null && profileImage!.isNotEmpty;

  UserModel copyWith({
    String? uid,
    int? id,
    String? name,
    String? email,
    String? role,
    String? phone,
    String? rollNo,
    String? regNo,
    String? department,
    String? semester,
    String? profileImage,
    bool? isVerified,
    bool? isBlocked,
    Map<String, dynamic>? defaultStop,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      rollNo: rollNo ?? this.rollNo,
      regNo: regNo ?? this.regNo,
      department: department ?? this.department,
      semester: semester ?? this.semester,
      profileImage: profileImage ?? this.profileImage,
      isVerified: isVerified ?? this.isVerified,
      isBlocked: isBlocked ?? this.isBlocked,
      defaultStop: defaultStop ?? this.defaultStop,
    );
  }
}
