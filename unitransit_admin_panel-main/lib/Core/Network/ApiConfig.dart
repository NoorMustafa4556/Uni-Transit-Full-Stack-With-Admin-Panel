class ApiConfig {
  // Default URL for Admin Panel (Web / Windows Desktop / Local Dev)
  // For production deployment, update to your deployed backend domain (e.g. 'https://api.unitransit.iub.edu.pk/api/v1')
  static String baseUrl = 'http://127.0.0.1:8000/api/v1';

  // WebSocket Base URL
  static String wsBaseUrl = 'ws://127.0.0.1:8000/ws';

  // Auth & Admin User Endpoints
  static const String login = '/auth/login/';
  static const String refreshToken = '/auth/token/refresh/';
  static const String me = '/auth/me/';
  static const String changePassword = '/auth/change-password/';

  // User Management
  static const String adminStudents = '/admin/students/';
  static String adminStudentStatus(int id) => '/admin/students/$id/status/';
  static const String adminDrivers = '/admin/drivers/';
  static String adminDriverStatus(int id) => '/admin/drivers/$id/status/';
  static const String adminAdmins = '/admin/admins/';

  // Backward compatibility aliases
  static const String adminUsers = '/admin/students/';
  static String adminUserDetail(int id) => '/admin/students/$id/status/';
  static String blockUser(int id) => '/admin/students/$id/status/';
  static String unblockUser(int id) => '/admin/students/$id/status/';
  static String verifyUser(int id) => '/admin/students/$id/status/';
  static String resetUserPassword(int id) => '/admin/students/$id/status/';

  // Transit Endpoints
  static const String hubs = '/transit/hubs/';
  static String hubDetail(int id) => '/transit/hubs/$id/';
  static const String stops = '/transit/stops/';
  static String stopDetail(int id) => '/transit/stops/$id/';
  static const String routes = '/transit/routes/';
  static String routeDetail(int id) => '/transit/routes/$id/';
  static const String routeCategories = '/transit/route-categories/';
  static String routeCategoryDetail(int id) => '/transit/route-categories/$id/';
  static const String routeTags = '/transit/route-tags/';
  static String routeTagDetail(int id) => '/transit/route-tags/$id/';
  static const String genderCategories = '/transit/gender-categories/';
  static String genderCategoryDetail(int id) => '/transit/gender-categories/$id/';
  static const String buses = '/transit/buses/';
  static String busDetail(int id) => '/transit/buses/$id/';

  // Schedules Endpoints
  static const String scheduleProfiles = '/schedules/profiles/';
  static String scheduleProfileDetail(int id) => '/schedules/profiles/$id/';
  static String setActiveProfile(int id) => '/schedules/profiles/$id/set-active/';
  static const String timeSlots = '/schedules/time-slots/';
  static String timeSlotDetail(int id) => '/schedules/time-slots/$id/';
  static const String slotAssignments = '/schedules/slot-assignments/';
  static String slotAssignmentDetail(int id) => '/schedules/slot-assignments/$id/';
  static const String activeSlots = '/schedules/active-slots/';

  // Backward compatibility aliases for schedules
  static const String busAssignments = '/schedules/slot-assignments/';
  static String busAssignmentDetail(int id) => '/schedules/slot-assignments/$id/';
  static const String todayActiveSchedule = '/schedules/active-slots/';

  // Tracking & Live Fleet
  static const String activeTrips = '/tracking/admin/trips/active/';
  static const String tripsHistory = '/tracking/admin/trips/history/';
  static const String stopSkipAlerts = '/tracking/admin/stop-skip-alerts/';
  static const String analyticsSummary = '/tracking/admin/analytics/summary/';
  static String driverTripStop(int tripId) => '/tracking/driver/trips/$tripId/stop/';

  // Backward compatibility aliases for tracking
  static const String trips = '/tracking/admin/trips/history/';
  static String tripDetail(int id) => '/tracking/admin/trips/$id/';
  static const String liveFleet = '/tracking/admin/trips/active/';

  // Operations Endpoints
  static const String approvals = '/operations/approvals/';
  static String approvalDetail(int id) => '/operations/approvals/$id/';
  static String approveRequest(int id) => '/operations/approvals/$id/approve/';
  static String rejectRequest(int id) => '/operations/approvals/$id/reject/';

  static const String sos = '/operations/sos/';
  static String sosDetail(int id) => '/operations/sos/$id/';
  static String sosResolve(int id) => '/operations/sos/$id/resolve/';

  static const String tickets = '/operations/tickets/';
  static String ticketDetail(int id) => '/operations/tickets/$id/';
  static String ticketReply(int id) => '/operations/tickets/$id/';
  static String ticketClose(int id) => '/operations/tickets/$id/';

  static const String notifications = '/operations/notifications/';
  static const String broadcastNotification = '/operations/notifications/';
  static const String sendUserNotification = '/operations/notifications/';

  static const String auditLogs = '/operations/audit-logs/';
  static const String contacts = '/operations/contacts/';
  static String contactDetail(int id) => '/operations/contacts/$id/';
  static const String faqs = '/operations/faqs/';
  static String faqDetail(int id) => '/operations/faqs/$id/';
  static const String config = '/operations/config/';

  // WebSocket URL Generator
  static String adminFleetWs(String token) => '$wsBaseUrl/admin/fleet/?token=$token';
}
