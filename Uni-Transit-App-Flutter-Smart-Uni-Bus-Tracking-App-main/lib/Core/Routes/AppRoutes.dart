import 'package:flutter/material.dart';

// Auth & Splash
import '../../Views/SplashScreen.dart';
import '../../Views/Auth/LoginScreen.dart';
import '../../Views/Auth/SignupScreen.dart';
import '../../Views/Auth/ForgotPasswordScreen.dart';

// Common
import '../../Views/Common/CompleteProfileScreen.dart';
import '../../Views/OnboardingScreen.dart';
import '../../Views/Common/ProfileScreen.dart';
import '../../Views/Common/SettingsScreen.dart';
import '../../Views/Common/AboutScreen.dart';
import '../../Views/Common/HelpSupportScreen.dart';
import '../../Views/Student/StudentProfileScreen.dart';
import '../../Views/Driver/DriverProfileScreen.dart';

// Dashboards & Tracking
import '../../Views/Driver/DriverDashboard.dart';
import '../../Views/Driver/UnverifiedDriverScreen.dart';
import '../../Views/Driver/BlockedDriverScreen.dart';
import '../../Views/Student/StudentDashboard.dart';
import '../../Views/Student/BlockedStudentScreen.dart';
import '../../Views/Admin/AdminDashboard.dart';
import '../../Views/LiveTrackingScreen.dart';
import '../../Views/AddScheduleScreen.dart';
import '../../Views/Driver/TripHistoryScreen.dart';
import '../../Views/Common/NotificationsScreen.dart';


class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot_password';
  static const String completeProfile = '/complete_profile';
  static const String profile = '/profile';
  static const String studentProfile = '/student_profile';
  static const String driverProfile = '/driver_profile';
  static const String settings = '/settings';
  static const String tracking = '/tracking';
  static const String driverDashboard = '/driver_dashboard';
  static const String unverifiedDriver = '/unverified_driver';
  static const String blockedDriver = '/blocked_driver';
  static const String blockedStudent = '/blocked_student';
  static const String studentDashboard = '/student_dashboard';
  static const String adminDashboard = '/admin_dashboard';
  static const String addSchedule = '/add_schedule';
  static const String tripHistory = '/trip_history';
  static const String support = '/support';
  static const String about = '/about';
  static const String notifications = '/notifications';


  static Map<String, WidgetBuilder> getRoutes() {
    return {
      splash: (context) => const SplashScreen(),
      onboarding: (context) => const OnboardingScreen(),
      login: (context) => const LoginScreen(),
      signup: (context) => const SignUpScreen(),
      forgotPassword: (context) => const ForgotPasswordScreen(),
      completeProfile: (context) => const CompleteProfileScreen(),
      profile: (context) => const ProfileScreen(),
      studentProfile: (context) => const StudentProfileScreen(),
      driverProfile: (context) => const DriverProfileScreen(),
      settings: (context) => const SettingsScreen(),
      tracking: (context) => const LiveTrackingScreen(),
      driverDashboard: (context) => const DriverDashboard(),
      unverifiedDriver: (context) => const UnverifiedDriverScreen(),
      blockedDriver: (context) => const BlockedDriverScreen(),
      blockedStudent: (context) => const BlockedStudentScreen(),
      studentDashboard: (context) => const StudentDashboard(),
      adminDashboard: (context) => const AdminDashboard(),
      addSchedule: (context) => const AddScheduleScreen(),
      tripHistory: (context) => const TripHistoryScreen(),
      support: (context) => const HelpSupportScreen(),
      about: (context) => const AboutScreen(),
      notifications: (context) => const NotificationsScreen(),

    };
  }
}
