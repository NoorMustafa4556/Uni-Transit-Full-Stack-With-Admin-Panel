import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uni_transit/Services/NotificationService.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'Core/Theme/AppTheme.dart';
import 'ViewModels/ThemeProvider.dart';
import 'ViewModels/AppInfoProvider.dart';
import 'Core/Routes/AppRoutes.dart';
import 'Views/SplashScreen.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    final sharedPreferences = await SharedPreferences.getInstance();
    await NotificationService.init();

    PaintingBinding.instance.imageCache.maximumSize = 50; 
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024; 

    GoogleFonts.config.allowRuntimeFetching = true;

    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e, stack) {
    debugPrint("CRITICAL ERROR: $e");
    runApp(MaterialApp(home: Scaffold(body: Center(child: Text("App failed to start:\n\n$e")))));
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appInfoAsync = ref.watch(appInfoProvider);
    final themeMode = ref.watch(themeProvider);

    // Fallbacks while app information is loading
    ThemeData theme = AppTheme.lightTheme;
    ThemeData darkTheme = AppTheme.lightTheme;
    String title = 'Uni-Transit';

    final appInfo = appInfoAsync.value;
    if (appInfo != null) {
      title = appInfo.appName;
      theme = AppTheme.createTheme(
        primaryHex: appInfo.primaryColor,
        accentHex: appInfo.accentColor,
        backgroundHex: appInfo.backgroundColor,
        cardHex: appInfo.cardColor,
        textPrimaryHex: appInfo.textPrimaryColor,
        textSecondaryHex: appInfo.textSecondaryColor,
      );
      darkTheme = AppTheme.createTheme(
        primaryHex: appInfo.primaryColor,
        accentHex: appInfo.accentColor,
        backgroundHex: appInfo.backgroundColor,
        cardHex: appInfo.cardColor,
        textPrimaryHex: appInfo.textPrimaryColor,
        textSecondaryHex: appInfo.textSecondaryColor,
        isDark: true,
      );
    }

    final routes = AppRoutes.getRoutes()..remove(AppRoutes.splash);

    return MaterialApp(
      title: title,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: NotificationService.messengerKey,
      themeMode: themeMode,
      theme: theme,
      darkTheme: darkTheme,
      home: appInfoAsync.when(
        data: (appInfo) => Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _precacheImages(context);
            });
            return const SplashScreen();
          },
        ),
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (e, stack) {
          debugPrint("CRITICAL APP ERROR: $e\n$stack");
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text("App Load Error: $e", textAlign: TextAlign.center),
              ),
            ),
          );
        },
      ),
      routes: routes,
    );
  }

  void _precacheImages(BuildContext context) {
    try {
      precacheImage(const AssetImage('assets/images/unitransit_logo.png'), context);
      precacheImage(const AssetImage('assets/images/tracking.png'), context);
      precacheImage(const AssetImage('assets/images/schedule.png'), context);
      precacheImage(const AssetImage('assets/images/safety.png'), context);
    } catch (e) {
      debugPrint("Precache images failed: $e");
    }
  }
}
