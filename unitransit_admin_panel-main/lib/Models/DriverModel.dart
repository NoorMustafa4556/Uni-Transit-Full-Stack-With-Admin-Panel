class DriverModel {
  final String id;
  final String name;
  final String phoneNumber;
  final String email;
  final String cnic;
  final String licenseNumber;
  final DateTime licenseExpiry;
  final String assignedBus;
  final List<String> assignedRoutes;
  final String experience;
  final String status; // 'Online', 'Offline', 'Busy'
  final String? cnicFrontUrl;
  final String? cnicBackUrl;
  final String? profileUrl;
  final String? licenseImageUrl;
  final bool isVerified;
  final bool isBlocked;
  final DateTime createdAt;

  DriverModel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.email,
    required this.cnic,
    required this.licenseNumber,
    required this.licenseExpiry,
    required this.assignedBus,
    this.assignedRoutes = const [],
    required this.experience,
    required this.status,
    this.cnicFrontUrl,
    this.cnicBackUrl,
    this.profileUrl,
    this.licenseImageUrl,
    this.isVerified = false,
    this.isBlocked = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'cnic': cnic,
      'licenseNumber': licenseNumber,
      'licenseExpiry': licenseExpiry.toIso8601String(),
      'assignedBus': assignedBus,
      'assignedRoutes': assignedRoutes,
      'experience': experience,
      'status': status,
      'cnicFrontUrl': cnicFrontUrl,
      'cnicBackUrl': cnicBackUrl,
      'profileUrl': profileUrl,
      'licenseImageUrl': licenseImageUrl,
      'isVerified': isVerified,
      'isBlocked': isBlocked,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DriverModel.fromMap(Map<String, dynamic> map) {
    DateTime parsedExpiry;
    try {
      final raw = map['licenseExpiry'] ?? map['license_expiry'];
      parsedExpiry = raw != null ? DateTime.parse(raw.toString()) : DateTime.now().add(const Duration(days: 365));
    } catch (_) {
      parsedExpiry = DateTime.now().add(const Duration(days: 365));
    }

    DateTime parsedCreated;
    try {
      final raw = map['createdAt'] ?? map['created_at'];
      parsedCreated = raw != null ? DateTime.parse(raw.toString()) : DateTime.now();
    } catch (_) {
      parsedCreated = DateTime.now();
    }

    final driverProfile = map['driver_profile'] as Map<String, dynamic>? ?? {};

    return DriverModel(
      id: (map['id'] ?? map['uid'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      phoneNumber: (map['phoneNumber'] ?? map['phone'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      cnic: (map['cnic'] ?? driverProfile['cnic'] ?? '').toString(),
      licenseNumber: (map['licenseNumber'] ?? driverProfile['license_number'] ?? '').toString(),
      licenseExpiry: parsedExpiry,
      assignedBus: (map['assignedBus'] ?? driverProfile['assigned_bus'] ?? '').toString(),
      assignedRoutes: map['assignedRoutes'] != null
          ? List<String>.from(map['assignedRoutes'])
          : (map['assigned_routes'] != null ? List<String>.from(map['assigned_routes']) : const []),
      experience: (map['experience'] ?? driverProfile['experience'] ?? '3+ Years').toString(),
      status: (map['status'] ?? (map['is_verified'] == true ? 'Online' : 'Offline')).toString(),
      cnicFrontUrl: map['cnicFrontUrl'] ?? driverProfile['cnic_front_image'],
      cnicBackUrl: map['cnicBackUrl'] ?? driverProfile['cnic_back_image'],
      profileUrl: map['profileUrl'] ?? map['profile_image'],
      licenseImageUrl: map['licenseImageUrl'] ?? driverProfile['license_image'],
      isVerified: map['isVerified'] ?? map['is_verified'] ?? false,
      isBlocked: map['isBlocked'] ?? map['is_blocked'] ?? false,
      createdAt: parsedCreated,
    );
  }

  DriverModel copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? email,
    String? cnic,
    String? licenseNumber,
    DateTime? licenseExpiry,
    String? assignedBus,
    List<String>? assignedRoutes,
    String? experience,
    String? status,
    String? cnicFrontUrl,
    String? cnicBackUrl,
    String? profileUrl,
    String? licenseImageUrl,
    bool? isVerified,
    bool? isBlocked,
    DateTime? createdAt,
  }) {
    return DriverModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      cnic: cnic ?? this.cnic,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      licenseExpiry: licenseExpiry ?? this.licenseExpiry,
      assignedBus: assignedBus ?? this.assignedBus,
      assignedRoutes: assignedRoutes ?? this.assignedRoutes,
      experience: experience ?? this.experience,
      status: status ?? this.status,
      cnicFrontUrl: cnicFrontUrl ?? this.cnicFrontUrl,
      cnicBackUrl: cnicBackUrl ?? this.cnicBackUrl,
      profileUrl: profileUrl ?? this.profileUrl,
      licenseImageUrl: licenseImageUrl ?? this.licenseImageUrl,
      isVerified: isVerified ?? this.isVerified,
      isBlocked: isBlocked ?? this.isBlocked,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
