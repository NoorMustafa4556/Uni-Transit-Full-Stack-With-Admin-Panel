import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uni_transit/Core/Constants/AppColors.dart';
import 'package:uni_transit/Widgets/AppDrawer.dart';
import 'package:uni_transit/Widgets/CustomAppBar.dart';
import 'package:uni_transit/Core/Routes/AppRoutes.dart';
import 'package:uni_transit/ViewModels/AuthProvider.dart';

import 'MapScreen.dart';
import 'ScheduleScreen.dart';

class StudentNavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index;
  }
}

final studentNavIndexProvider = NotifierProvider<StudentNavIndexNotifier, int>(() {
  return StudentNavIndexNotifier();
});

class StudentDashboard extends ConsumerStatefulWidget {
  const StudentDashboard({super.key});

  @override
  ConsumerState<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends ConsumerState<StudentDashboard> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Map<String, dynamic>?>>(userProfileProvider, (previous, next) {
      if (next.hasValue) {
        if (next.value == null) {
          if (ref.read(authStateProvider).value == null) return;
          ref.read(authStateProvider.notifier).logout();
          Navigator.pushReplacementNamed(context, AppRoutes.login);
          return;
        }

        final isBlocked = next.value?['is_blocked'] == true || next.value?['isBlocked'] == true;
        if (isBlocked) {
          Navigator.pushReplacementNamed(context, AppRoutes.blockedStudent);
        }
      }
    });

    final currentIndex = ref.watch(studentNavIndexProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      appBar: CustomAppBar(
        title: currentIndex == 0 ? "STUDENT DASHBOARD" : "SCHEDULE",
        showLogo: false,
        showBackArrow: false,
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: IndexedStack(
        index: currentIndex,
        children: const [
          MapScreen(),
          ScheduleScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black26 : AppColors.primaryNavy.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) {
              ref.read(studentNavIndexProvider.notifier).setIndex(index);
            },
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            indicatorColor: isDark ? AppColors.primaryYellow.withValues(alpha: 0.2) : AppColors.primaryNavy.withValues(alpha: 0.1),
            elevation: 0,
            height: 64,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.gps_fixed_outlined, color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant),
                selectedIcon: Icon(Icons.gps_fixed, color: isDark ? AppColors.primaryYellow : AppColors.primaryNavy),
                label: 'Live Track',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined, color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant),
                selectedIcon: Icon(Icons.calendar_today, color: isDark ? AppColors.primaryYellow : AppColors.primaryNavy),
                label: 'Schedule',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
