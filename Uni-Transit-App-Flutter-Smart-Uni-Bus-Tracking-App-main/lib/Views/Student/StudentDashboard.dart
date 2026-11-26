import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_transit/Core/Constants/AppColors.dart';
import 'package:uni_transit/Widgets/AppDrawer.dart';
import 'package:uni_transit/Widgets/CustomAppBar.dart';
import 'package:uni_transit/Core/Routes/AppRoutes.dart';
import 'package:uni_transit/ViewModels/AuthProvider.dart';
import 'package:uni_transit/Services/NotificationService.dart';
import 'package:uni_transit/Views/Common/SosReviewBottomSheet.dart';

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
  StreamSubscription? _notificationSubscription;
  final DateTime _appStartTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    // ⚡ PRO-CHOICE: Update student status to Active immediately
    _updateStatus('Active');
    _listenForPushNotifications();
    
    // Check for pending review from resolved SOS on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForPendingSosReviews();
    });
  }

  Future<void> _checkForPendingSosReviews() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final snapshot = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('user_id', uid)
          .eq('type', 'sos_resolved');

      final unreviewedDocs = snapshot.where((doc) {
        return doc['is_reviewed'] != true && doc['alert_id'] != null;
      }).toList();

      if (unreviewedDocs.isNotEmpty && mounted) {
        final doc = unreviewedDocs.first;
        final alertId = doc['alert_id'].toString();
        final message = doc['message'] ?? 'SOS Alert Resolved';

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => SosReviewBottomSheet(
            notificationId: doc['id'].toString(),
            alertId: alertId,
            alertMessage: message,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error checking for pending SOS reviews: $e");
    }
  }

  void _listenForPushNotifications() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    _notificationSubscription = Supabase.instance.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .listen((event) {
          for (var row in event) {
            final ts = DateTime.parse(row['timestamp'] ?? DateTime.now().toIso8601String());
            if (ts.isAfter(_appStartTime)) {
              final isRead = row['is_read'] ?? false;
              if (!isRead) {
                final title = row['title'] ?? 'New Support Alert';
                final message = row['message'] ?? '';
                
                NotificationService.showLocalNotification(
                  title: title,
                  body: message,
                );
                
                NotificationService.show(
                  title: title,
                  message: message,
                  type: NotificationType.info,
                );

                if (row['type'] == 'sos_resolved' && row['alert_id'] != null && row['is_reviewed'] != true) {
                  Future.delayed(const Duration(milliseconds: 1000), () {
                    if (mounted) {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => SosReviewBottomSheet(
                          notificationId: row['id'].toString(),
                          alertId: row['alert_id'].toString(),
                          alertMessage: message,
                        ),
                      );
                    }
                  });
                }
              }
            }
          }
        }, onError: (error) {
          debugPrint("Error listening for user notifications: $error");
        });
  }

  @override
  void dispose() {
    _updateStatus('Offline');
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _updateStatus(String status) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'status': status})
          .eq('id', uid);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Map<String, dynamic>?>>(userProfileProvider, (previous, next) {
      if (next.hasValue) {
        if (next.value == null) {
          if (Supabase.instance.client.auth.currentUser == null) return;
          ref.read(authStateProvider.notifier).logout();
          Navigator.pushReplacementNamed(context, AppRoutes.login);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your account has been deleted by the administration.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final isBlocked = next.value?['isBlocked'] == true || next.value?['isBlocked'] == 'true';

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
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client
                .from('notifications')
                .stream(primaryKey: ['id'])
                .eq('user_id', Supabase.instance.client.auth.currentUser?.id ?? '')
                .map((event) => event.where((row) => row['is_read'] == false).toList()),
            builder: (context, snapshot) {
              final bool hasUnread = snapshot.hasData && snapshot.data!.isNotEmpty;
              return IconButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
                icon: Badge(
                  isLabelVisible: hasUnread,
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.notifications_outlined),
                ),
              );
            },
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
