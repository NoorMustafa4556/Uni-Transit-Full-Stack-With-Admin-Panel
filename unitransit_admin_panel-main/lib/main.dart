import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unitransit_admin/Core/Constants/AppColors.dart';
import 'package:unitransit_admin/Core/Theme/AppTheme.dart';
import 'package:unitransit_admin/Core/Services/FirebaseService.dart';
import 'package:unitransit_admin/ViewModels/DashboardViewModel.dart';
import 'package:unitransit_admin/ViewModels/RoutePlanningViewModel.dart';
import 'package:unitransit_admin/ViewModels/DriversViewModel.dart';
import 'package:unitransit_admin/ViewModels/StudentsViewModel.dart';
import 'package:unitransit_admin/ViewModels/GenderConfigViewModel.dart';
import 'package:unitransit_admin/ViewModels/SupportViewModel.dart';
import 'package:unitransit_admin/ViewModels/AppSettingsViewModel.dart';
import 'package:unitransit_admin/ViewModels/LoginViewModel.dart';
import 'package:unitransit_admin/ViewModels/NotificationsViewModel.dart';
import 'package:unitransit_admin/ViewModels/FleetOperationsViewModel.dart';
import 'package:unitransit_admin/ViewModels/BusesViewModel.dart';
import 'package:unitransit_admin/Views/LoginScreen.dart';
import 'package:unitransit_admin/Views/SplashScreen.dart';
import 'package:unitransit_admin/Core/Util/CloudFirestoreCompat.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://eplzrubpbqsdmezvkjgz.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwbHpydWJwYnFzZG1lenZramd6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUxNDgxMjQsImV4cCI6MjEwMDcyNDEyNH0.l633BESZHDigcg9ViA_tmhkFdcxoACoKmcBRRbuyS8w',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );
  
  // Upload initial "About" info to Firebase/Supabase if it doesn't exist
  FirebaseService().uploadInitialAppInfo();

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => FirebaseService()),
        ChangeNotifierProvider(create: (_) => LoginViewModel()),
        ChangeNotifierProvider(create: (_) => DashboardViewModel()),
        ChangeNotifierProvider(
          create: (context) => RoutePlanningViewModel(
            Provider.of<FirebaseService>(context, listen: false),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => DriversViewModel(
            Provider.of<FirebaseService>(context, listen: false),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => StudentsViewModel(
            Provider.of<FirebaseService>(context, listen: false),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => GenderConfigViewModel(
            Provider.of<FirebaseService>(context, listen: false),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => SupportViewModel(
            Provider.of<FirebaseService>(context, listen: false),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => AppSettingsViewModel(
            Provider.of<FirebaseService>(context, listen: false),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => NotificationsViewModel(
            Provider.of<FirebaseService>(context, listen: false),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => FleetOperationsViewModel(),
        ),
        ChangeNotifierProvider(
          create: (_) => BusesViewModel(),
        ),
      ],
      child: const AdminPanelApp(),
    ),
  );
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

class AdminPanelApp extends StatelessWidget {
  const AdminPanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return SessionTimeoutWrapper(
      child: Consumer<AppSettingsViewModel>(
        builder: (context, viewModel, child) {
          return MaterialApp(
            title: 'Uni-Transit Admin',
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            scrollBehavior: MyCustomScrollBehavior(),
            theme: AppTheme.createTheme(
              primaryHex: viewModel.adminPrimaryColor,
              accentHex: viewModel.adminAccentColor,
              backgroundHex: viewModel.adminBackgroundColor,
              cardHex: viewModel.adminCardColor,
              textPrimaryHex: viewModel.adminTextPrimaryColor,
              textSecondaryHex: viewModel.adminTextSecondaryColor,
            ),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

class SessionTimeoutWrapper extends StatefulWidget {
  final Widget child;
  const SessionTimeoutWrapper({super.key, required this.child});

  @override
  State<SessionTimeoutWrapper> createState() => _SessionTimeoutWrapperState();
}

class _SessionTimeoutWrapperState extends State<SessionTimeoutWrapper> {
  Timer? _timer;
  static const _timeoutDuration = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(_timeoutDuration, _handleTimeout);
  }

  void _handleTimeout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseAuth.instance.signOut();
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
      // Show a snackbar or dialog if possible (optional)
    }
  }

  void _handleUserInteraction([_]) {
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handleUserInteraction,
      onPointerMove: _handleUserInteraction,
      onPointerHover: _handleUserInteraction,
      onPointerSignal: _handleUserInteraction,
      child: widget.child,
    );
  }
}
