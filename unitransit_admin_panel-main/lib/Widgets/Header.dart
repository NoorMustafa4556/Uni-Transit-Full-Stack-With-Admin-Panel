import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unitransit_admin/Core/Constants/AppColors.dart';
import 'package:unitransit_admin/Core/Services/AdminApiService.dart';
import 'package:unitransit_admin/Core/Utils/ResponsiveUtil.dart';
import 'package:unitransit_admin/ViewModels/DashboardViewModel.dart';
import 'package:unitransit_admin/ViewModels/LoginViewModel.dart';

class Header extends StatefulWidget {
  const Header({super.key});

  @override
  State<Header> createState() => _HeaderState();
}

class _HeaderState extends State<Header> {
  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DashboardViewModel>();
    final isSuperAdmin = context.read<LoginViewModel>().isSuperAdmin;

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: AppColors.backgroundLight,
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          if (!AppResponsiveUtil.isDesktop(context))
            IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu_rounded, color: AppColors.textDark),
            ),
          
          const Spacer(),

          // Approvals Quick Action Button
          _buildHeaderAction(
            context,
            Icons.approval_rounded,
            tooltip: 'Approvals Queue',
            onTap: () => viewModel.setSelectedIndex(20),
          ),

          const SizedBox(width: 16),
          
          _buildHeaderAction(
            context, 
            Icons.notifications_none_rounded, 
            badgeCount: viewModel.unreadNotificationsCount,
            tooltip: 'Notifications',
            onTap: () => viewModel.setSelectedIndex(8), // Notifications Index
          ),
          
          const SizedBox(width: 24),
          
          // User Profile Info
          FutureBuilder<Map<String, dynamic>?>(
            future: AdminApiService().getCurrentUser(),
            builder: (context, snapshot) {
              final user = snapshot.data;
              final name = user?['name']?.toString() ?? (isSuperAdmin ? 'Super Admin' : 'Sub Admin');
              final role = user?['role']?.toString().toUpperCase() ?? (isSuperAdmin ? 'SUPER ADMIN' : 'SUB ADMIN');
              final displayInitial = name.isNotEmpty ? name[0].toUpperCase() : 'A';

              return Row(
                children: [
                  if (!AppResponsiveUtil.isMobile(context) && !AppResponsiveUtil.isTablet(context))
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSuperAdmin ? Colors.amber.shade700 : AppColors.primaryNavy,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                role,
                                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                              ),
                            ),
                            Text(name, style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        Text(
                          _getPageSubtitle(viewModel.selectedIndex),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  const SizedBox(width: 16),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryNavy.withValues(alpha: 0.2), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.1),
                      child: Text(
                        displayInitial, 
                        style: const TextStyle(color: AppColors.primaryNavy, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _getPageSubtitle(int index) {
    switch (index) {
      case 0:
        return 'Dashboard Overview';
      case 1:
        return 'Students';
      case 2:
        return 'Drivers';
      case 3:
        return 'Admin Management';
      case 4:
        return 'Live Bus Tracking';
      case 5:
        return 'Route Planning';
      case 6:
        return 'Gender Config';
      case 7:
        return 'Trip History';
      case 8:
        return 'Notifications';
      case 9:
        return 'Support Center';
      case 10:
        return 'Settings';
      case 11:
        return 'Bus Schedules';
      case 12:
        return 'Emergency SOS';
      case 13:
        return 'Assign Routes';
      case 14:
        return 'Buses';
      case 15:
        return 'Audit Logs';
      case 16:
        return 'Analytics';
      case 17:
        return 'App Configuration';
      case 18:
        return 'Maintenance';
      case 19:
        return 'Safety Alerts';
      case 20:
        return 'Higher Authority Approvals';
      default:
        return 'Admin Panel';
    }
  }

  Widget _buildHeaderAction(BuildContext context, IconData icon, {int badgeCount = 0, String? tooltip, VoidCallback? onTap}) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Icon(icon, color: AppColors.textSecondary, size: 22),
            ),
            if (badgeCount > 0)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Center(
                    child: Text(
                      badgeCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
