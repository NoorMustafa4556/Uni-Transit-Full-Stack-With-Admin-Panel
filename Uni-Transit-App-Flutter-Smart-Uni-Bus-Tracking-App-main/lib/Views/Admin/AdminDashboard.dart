import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_transit/Core/Constants/AppColors.dart';
import 'package:uni_transit/Views/AddScheduleScreen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          "Admin Dashboard",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: AppColors.primaryNavy,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Overview Statistics",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 12),
            _buildStatsGrid(),
            const SizedBox(height: 24),
            Text(
              "Currently Active Buses",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 12),
            _buildActiveBusesList(),
            const SizedBox(height: 24),
            Text(
              "Recent SOS Alerts",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 12),
            _buildEmergencyAlerts(),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddScheduleScreen()),
        ),
        backgroundColor: AppColors.primaryYellow,
        foregroundColor: AppColors.primaryNavy,
        icon: const Icon(Icons.add_rounded),
        label: Text("Add Schedule", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('active_buses')
          .stream(primaryKey: ['bus_number']),
      builder: (context, busSnapshot) {
        int activeBuses = busSnapshot.data?.length ?? 0;

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: Supabase.instance.client
              .from('profiles')
              .stream(primaryKey: ['id']),
          builder: (context, userSnapshot) {
            int totalUsers = userSnapshot.data?.length ?? 0;
            int studentCount = 0;
            int driverCount = 0;
            
            if (userSnapshot.hasData) {
              for (var row in userSnapshot.data!) {
                final role = row['role']?.toString() ?? '';
                if (role == 'Student') studentCount++;
                if (role == 'Driver') driverCount++;
              }
            }

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.4,
              children: [
                _StatCard(
                  icon: Icons.directions_bus_rounded,
                  label: "Live Buses",
                  value: "$activeBuses",
                  color: AppColors.liveStatus,
                ),
                _StatCard(
                  icon: Icons.people_alt_rounded,
                  label: "Total Users",
                  value: "$totalUsers",
                  color: AppColors.primaryNavy,
                ),
                _StatCard(
                  icon: Icons.school_rounded,
                  label: "Students",
                  value: "$studentCount",
                  color: AppColors.boysSpecial,
                ),
                _StatCard(
                  icon: Icons.local_shipping_rounded,
                  label: "Drivers",
                  value: "$driverCount",
                  color: AppColors.combined,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildActiveBusesList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('active_buses')
          .stream(primaryKey: ['bus_number']),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                "No buses currently active",
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
              ),
            ),
          );
        }

        final buses = snapshot.data!;
        return Column(
          children: buses.map((row) {
            final busNum = row['bus_number']?.toString() ?? 'Unknown';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.liveStatus.withValues(alpha: 0.3)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.liveStatus.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.directions_bus_rounded, color: AppColors.liveStatus, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("BUS #$busNum", style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryNavy)),
                        Text("${row['from_hub']} ➔ ${row['to_hub']}", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
                        Text("Driver: ${row['driver_name'] ?? 'Unknown'}", style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.liveStatus,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text("LIVE", style: GoogleFonts.poppins(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildEmergencyAlerts() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('emergency_alerts')
          .stream(primaryKey: ['id'])
          .limit(5),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                "No emergency alerts",
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
              ),
            ),
          );
        }

        final alerts = snapshot.data!;
        // Sort alerts by timestamp descending
        final sortedAlerts = List<Map<String, dynamic>>.from(alerts)
          ..sort((a, b) {
            final aTime = DateTime.parse(a['timestamp'] ?? DateTime.now().toIso8601String());
            final bTime = DateTime.parse(b['timestamp'] ?? DateTime.now().toIso8601String());
            return bTime.compareTo(aTime);
          });

        return Column(
          children: sortedAlerts.map((row) {
            final isActive = row['status'] == 'active';
            final userName = row['user_name'] ?? 'Unknown';
            final message = row['message'] ?? 'SOS Alert';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isActive ? AppColors.error.withValues(alpha: 0.05) : Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isActive ? AppColors.error.withValues(alpha: 0.3) : Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    color: isActive ? AppColors.error : Colors.grey,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text(message, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.error : Colors.grey,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isActive ? "ACTIVE" : "RESOLVED",
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const Spacer(),
          Text(value, style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}
