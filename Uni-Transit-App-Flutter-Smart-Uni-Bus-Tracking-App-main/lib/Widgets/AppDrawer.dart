import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uni_transit/Core/Constants/AppColors.dart';
import 'package:uni_transit/Core/Constants/AppAssets.dart';
import 'package:uni_transit/ViewModels/AuthProvider.dart';
import 'package:uni_transit/ViewModels/DriverTripProvider.dart';
import 'package:uni_transit/ViewModels/ThemeProvider.dart';
import 'package:uni_transit/Views/Driver/TripHistoryScreen.dart';
import 'package:uni_transit/Views/Student/StudentDashboard.dart';

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  void _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Logout", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to end your session?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel", style: TextStyle(color: Colors.grey[600]))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Logout", style: TextStyle(color: AppColors.error))),
        ],
      ),
    );

    if (confirmed == true) {
      ref.invalidate(driverTripProvider);
      ref.read(authStateProvider.notifier).logout();
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  void _navigateToStudentTab(int index) {
    Navigator.pop(context);
    ref.read(studentNavIndexProvider.notifier).setIndex(index);
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute != '/student_dashboard') {
      Navigator.pushNamedAndRemoveUntil(context, '/student_dashboard', (route) => false);
    }
  }

  void _navigateTopLevel(String routeName) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute != routeName) {
      Navigator.pop(context); // Close drawer
      Navigator.pushNamed(context, routeName); // Instant push
    } else {
      Navigator.pop(context); // Just close if already there
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final userProfileAsync = ref.watch(userProfileProvider);
    final userData = userProfileAsync.value;
    final String userRole = userData?['role'] ?? 'Student';

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Column(children: [
        _buildHeader(userData, isLoading: userProfileAsync.isLoading && userData == null),
        Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          const SizedBox(height: 20),
          _buildSectionTitle("MAIN NAVIGATION"),
          ..._buildNavItems(userRole),
          const SizedBox(height: 20),
          _buildSectionTitle("ACCOUNT"),
          _DrawerTile(
            icon: Icons.person_outline_rounded, 
            title: "My Profile", 
            onTap: () {
              final role = userProfileAsync.value?['role'] ?? 'Student';
              _navigateTopLevel(role == 'Driver' ? '/driver_profile' : '/student_profile');
            },
          ),
          _DrawerTile(
            icon: ref.watch(themeProvider) == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            title: ref.watch(themeProvider) == ThemeMode.dark ? "Switch to Light Mode" : "Switch to Dark Mode",
            onTap: () {
              final current = ref.read(themeProvider);
              ref.read(themeProvider.notifier).toggleTheme(current != ThemeMode.dark);
            },
          ),
          const SizedBox(height: 20),
          _buildSectionTitle("SUPPORT & INFO"),
          _DrawerTile(icon: Icons.help_outline_rounded, title: "Support", onTap: () => _navigateTopLevel('/support')),
          _DrawerTile(icon: Icons.info_outline_rounded, title: "About App", onTap: () => _navigateTopLevel('/about')),
        ])),
        _buildFooter(),
      ]),
    );
  }

  List<Widget> _buildNavItems(String role) {
    if (role == 'Student') {
      return [
        _DrawerTile(icon: Icons.directions_bus_rounded, title: "Live Tracking", onTap: () => _navigateToStudentTab(0)),
        _DrawerTile(icon: Icons.map_outlined, title: "Bus Routes", onTap: () => _navigateToStudentTab(0)),
        _DrawerTile(icon: Icons.calendar_month_rounded, title: "Schedule", onTap: () => _navigateToStudentTab(1)),
      ];
    } else if (role == 'Driver') {
      return [
        _DrawerTile(icon: Icons.dashboard_rounded, title: "Driver Dashboard", onTap: () {
          Navigator.pop(context); // Close the drawer
          
          final currentRoute = ModalRoute.of(context)?.settings.name;
          if (currentRoute == '/driver_dashboard') {
            return; // Already on dashboard, do nothing
          }

          bool hasDashboard = false;
          Navigator.popUntil(context, (route) {
            if (route.settings.name == '/driver_dashboard') {
              hasDashboard = true;
              return true;
            }
            return route.isFirst;
          });

          if (!hasDashboard) {
            Navigator.pushNamedAndRemoveUntil(context, '/driver_dashboard', (r) => false);
          }
        }),
        _DrawerTile(icon: Icons.history_rounded, title: "My Trip History", onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const TripHistoryScreen())); }),
      ];
    } else if (role == 'Admin') {
      return [
        _DrawerTile(icon: Icons.admin_panel_settings_rounded, title: "Admin Panel", onTap: () { Navigator.pop(context); Navigator.pushNamedAndRemoveUntil(context, '/admin_dashboard', (r) => false); }),
        _DrawerTile(icon: Icons.add_circle_outline_rounded, title: "Add Schedule", onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/add_schedule'); }),
        _DrawerTile(icon: Icons.track_changes_rounded, title: "Live Overview", onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/tracking'); }),
      ];
    }
    return [];
  }

  Widget _buildSectionTitle(String title) {
    return Padding(padding: const EdgeInsets.only(left: 12, bottom: 8, top: 12), child: Text(title, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[500], letterSpacing: 1.2)));
  }

  Widget _buildHeader(Map<String, dynamic>? userData, {bool isLoading = false}) {
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.value;
    String name = isLoading ? "Loading..." : (userData?['name'] ?? "Welcome User");
    String email = currentUser?.email ?? (isLoading ? "..." : "uni.transit@iub.edu.pk");
    String role = userData?['role'] ?? "Student";
    String profileUrl = userData?['profileImage'] ?? userData?['profile_image'] ?? userData?['profileImageUrl'] ?? "";

    return Container(
      width: double.infinity, padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20, bottom: 20, left: 24, right: 24),
      decoration: const BoxDecoration(color: AppColors.primaryNavy, borderRadius: BorderRadius.only(bottomRight: Radius.circular(40))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primaryYellow, width: 2)), child: CircleAvatar(radius: 35, backgroundColor: Colors.white10, backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null, child: profileUrl.isEmpty ? Icon(isLoading ? Icons.hourglass_empty : Icons.person, color: Colors.white, size: 35) : null)),
          if (!isLoading) Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: AppColors.primaryYellow, borderRadius: BorderRadius.circular(20)), child: Text(role.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black))),
        ]),
        const SizedBox(height: 20),
        if (isLoading) Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 150, height: 24, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4))), const SizedBox(height: 8), Container(width: 100, height: 16, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)))])
        else Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)), Text(email, style: GoogleFonts.poppins(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)))])
      ]),
    );
  }

  Widget _buildFooter() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!))),
      child: Column(children: [
        _DrawerTile(icon: Icons.logout_rounded, title: "Sign Out", iconColor: AppColors.error, textColor: AppColors.error, onTap: _logout),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ClipOval(
            child: Image.asset(AppAssets.iubLogo, height: 20, width: 20, fit: BoxFit.cover),
          ), 
          const SizedBox(width: 10), 
          Text("UniTransit v1.2.0", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[400]))
        ]),
      ]),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  const _DrawerTile({required this.icon, required this.title, required this.onTap, this.iconColor, this.textColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return ListTile(
      leading: Icon(icon, color: iconColor ?? (isDark ? Colors.white.withValues(alpha: 0.7) : AppColors.primaryNavy.withValues(alpha: 0.7))),
      title: Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: textColor ?? (isDark ? Colors.white : AppColors.textDark))),
      dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), onTap: onTap,
    );
  }
}
