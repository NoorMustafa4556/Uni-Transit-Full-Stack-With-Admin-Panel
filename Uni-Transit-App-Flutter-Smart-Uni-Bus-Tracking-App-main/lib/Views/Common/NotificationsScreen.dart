import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uni_transit/Core/Constants/AppColors.dart';
import 'package:uni_transit/Core/Network/ApiClient.dart';
import 'package:uni_transit/Core/Network/ApiConfig.dart';
import 'package:uni_transit/Widgets/CustomAppBar.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiClient _api = ApiClient();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String _selectedFilter = 'All'; // All, Unread

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get(ApiConfig.notifications);
      if (res.statusCode == 200 && res.data != null) {
        final List list = res.data is List ? res.data : (res.data['results'] ?? []);
        if (mounted) {
          setState(() {
            _notifications = list.map((e) => Map<String, dynamic>.from(e)).toList();
            _isLoading = false;
          });
        }
        return;
      }
    } catch (_) {}

    // Fallback notifications if empty
    if (mounted) {
      setState(() {
        _notifications = [
          {
            "id": 1,
            "title": "Welcome to UniTransit 2026",
            "message": "Real-time bus tracking and schedule slot alerts are active for all IUB campuses.",
            "is_read": true,
            "created_at": "Today",
          },
        ];
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(int id) async {
    try {
      await _api.post(ApiConfig.notificationRead(id));
      setState(() {
        final idx = _notifications.indexWhere((n) => n['id'] == id);
        if (idx != -1) _notifications[idx]['is_read'] = true;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _notifications.where((n) {
      if (_selectedFilter == 'Unread') {
        return n['is_read'] == false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: CustomAppBar(
        title: "Notifications",
        showBackArrow: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy))
          : Column(
              children: [
                // Filter chips
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text("All"),
                        selected: _selectedFilter == 'All',
                        selectedColor: AppColors.primaryNavy,
                        labelStyle: TextStyle(
                          color: _selectedFilter == 'All' ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (s) => setState(() => _selectedFilter = 'All'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text("Unread"),
                        selected: _selectedFilter == 'Unread',
                        selectedColor: AppColors.primaryNavy,
                        labelStyle: TextStyle(
                          color: _selectedFilter == 'Unread' ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (s) => setState(() => _selectedFilter = 'Unread'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.borderLight),

                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text("No notifications found", style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final isRead = item['is_read'] == true;

                            return InkWell(
                              onTap: () {
                                if (!isRead && item['id'] is int) {
                                  _markAsRead(item['id']);
                                }
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isRead ? Colors.grey.shade200 : AppColors.primaryNavy.withValues(alpha: 0.3),
                                    width: isRead ? 1 : 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isRead ? Colors.grey.shade100 : AppColors.primaryNavy.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.notifications_active_rounded,
                                        size: 20,
                                        color: isRead ? Colors.grey : AppColors.primaryNavy,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['title'] ?? 'Notification',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item['message'] ?? '',
                                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!isRead)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.blue,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
