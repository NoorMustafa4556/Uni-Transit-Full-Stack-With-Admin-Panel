class ApiConfig {
  // Use http://10.0.2.2:8000/api/v1 for Android Emulator.
  // For physical Android/iOS devices on Wi-Fi, change to your PC's LAN IP e.g. 'http://192.168.1.100:8000/api/v1'
  // For Chrome/Windows desktop testing, use 'http://127.0.0.1:8000/api/v1'
  static String baseUrl = 'http://10.0.2.2:8000/api/v1';

  // WebSocket base URL
  // Android Emulator: ws://10.0.2.2:8000/ws
  // Physical device: ws://192.168.1.100:8000/ws
  // Chrome/Windows: ws://127.0.0.1:8000/ws
  static String wsBaseUrl = 'ws://10.0.2.2:8000/ws';

  // Endpoints
  // Auth
  static const String login = '/auth/login/';
  static const String register = '/auth/register/';
  static const String refreshToken = '/auth/token/refresh/';
  static const String me = '/auth/me/';
  static const String fcmToken = '/auth/fcm-token/';
  static const String changePassword = '/auth/change-password/';

  // Transit
  static const String hubs = '/transit/hubs/';
  static const String routeCategories = '/transit/route-categories/';
  static const String routeTags = '/transit/route-tags/';
  static const String genderCategories = '/transit/gender-categories/';
  static const String stops = '/transit/stops/';
  static const String routes = '/transit/routes/';
  static const String buses = '/transit/buses/';

  // Schedules
  static const String scheduleProfiles = '/schedules/profiles/';
  static const String activeSlots = '/schedules/active-slots/';

  // Tracking
  static const String driverTripStart = '/tracking/driver/trips/start/';
  static String driverTripStop(int tripId) => '/tracking/driver/trips/$tripId/stop/';
  static String driverTripCrowdStatus(int tripId) => '/tracking/driver/trips/$tripId/crowd-status/';
  static String driverTripAlert(int tripId) => '/tracking/driver/trips/$tripId/alert/';
  static String driverTripLocation(int tripId) => '/tracking/driver/trips/$tripId/location/';
  static const String driverActiveTrip = '/tracking/driver/trips/active/';
  static const String driverTripHistory = '/tracking/driver/trips/history/';
  static const String studentStopFeed = '/tracking/student/stop-feed/';

  // Operations
  static const String sos = '/operations/sos/';
  static String sosResolve(int id) => '/operations/sos/$id/resolve/';
  static String sosReview(int id) => '/operations/sos/$id/review/';
  static const String tickets = '/operations/tickets/';
  static String ticketDetail(int id) => '/operations/tickets/$id/';
  static const String notifications = '/operations/notifications/';
  static String notificationRead(int id) => '/operations/notifications/$id/read/';
  static const String contacts = '/operations/contacts/';
  static const String faqs = '/operations/faqs/';
  static const String config = '/operations/config/';
}
