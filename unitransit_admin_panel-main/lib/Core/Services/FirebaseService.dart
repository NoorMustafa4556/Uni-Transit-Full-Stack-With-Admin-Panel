// Migration compatibility wrapper: delegates directly to AdminApiService
// All backend logic runs against Django REST and Channels WebSockets.
import 'package:unitransit_admin/Core/Services/AdminApiService.dart';

class FirebaseService extends AdminApiService {
  static final FirebaseService _compatInstance = FirebaseService._internal();
  factory FirebaseService() => _compatInstance;
  FirebaseService._internal() : super.internal();
}
