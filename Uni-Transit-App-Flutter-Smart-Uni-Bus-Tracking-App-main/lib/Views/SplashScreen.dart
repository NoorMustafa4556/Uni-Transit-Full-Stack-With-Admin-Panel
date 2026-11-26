import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni_transit/Core/Constants/AppColors.dart';
import 'package:uni_transit/Core/Constants/AppAssets.dart';
import 'package:uni_transit/Core/Util/Logger.dart';
import 'package:uni_transit/Services/AuthService.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 3));

    final prefs = await SharedPreferences.getInstance();
    final bool onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

    if (!onboardingCompleted) {
      if (mounted) Navigator.pushReplacementNamed(context, '/onboarding');
      return;
    }

    if (!mounted) return;

    final user = _authService.currentUser;
    if (user != null) {
      if (!mounted) return;
      String? role = prefs.getString('user_role');

      if (role == null) {
        try {
          role = await _authService.getUserRole(user.uid)
              .timeout(const Duration(seconds: 5), onTimeout: () => null);
          if (role != null) await prefs.setString('user_role', role);
        } catch (e) {
          AppLogger.error("Error fetching role: $e");
        }
      }

      if (mounted) {
        String routeName = '/login';
        final roleLower = role?.toLowerCase().trim();
        if (roleLower == 'student') {
          routeName = user.isBlocked ? '/blocked_student' : '/student_dashboard';
        } else if (roleLower == 'driver') {
          if (user.isBlocked) {
            routeName = '/blocked_driver';
          } else if (user.isVerified) {
            routeName = '/driver_dashboard';
          } else {
            routeName = '/unverified_driver';
          }
        } else if (roleLower == 'admin') {
          routeName = '/admin_dashboard';
        }
        Navigator.pushReplacementNamed(context, routeName);
      }
    } else {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryNavy, 
              Color(0xFF1E293B),
            ],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white, // Solid white so it blends with logo background
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Hero(
                            tag: 'app_logo',
                            child: Image.asset(
                              AppAssets.iubLogo, 
                              height: 130,
                              width: 130,
                              fit: BoxFit.cover, // Ensures the square image perfectly fills the circle
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        "UNITRANSIT",
                        style: GoogleFonts.poppins(
                          fontSize: 42,
                          letterSpacing: 8,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 4,
                        width: 60,
                        decoration: BoxDecoration(
                          color: AppColors.primaryYellow,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryYellow.withValues(alpha: 0.4),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: AnimatedBuilder(
                      animation: _fadeAnimation,
                      builder: (context, child) {
                        return CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withValues(alpha: 0.24 * _fadeAnimation.value),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      "THE ISLAMIA UNIVERSITY OF BAHAWALPUR",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        letterSpacing: 3,
                        color: Colors.white38,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
