import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uni_transit/Core/Constants/AppColors.dart';
import 'package:uni_transit/Core/Network/ApiClient.dart';
import 'package:uni_transit/Core/Network/ApiConfig.dart';
import 'package:uni_transit/Core/Routes/AppRoutes.dart';
import 'package:uni_transit/ViewModels/BusProvider.dart';
import 'package:uni_transit/Widgets/AppDrawer.dart';
import 'package:uni_transit/Widgets/CustomAppBar.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  final ApiClient _api = ApiClient();
  List<Map<String, dynamic>> _sosAlerts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get(ApiConfig.sos);
      if (res.statusCode == 200 && res.data != null) {
        final List list = res.data is List ? res.data : (res.data['results'] ?? []);
        setState(() {
          _sosAlerts = list.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final liveBuses = ref.watch(busProvider).liveBusData;
    final int activeBusesCount = liveBuses.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(title: "ADMIN CONTROL CENTER", showBackArrow: false),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: _loadAlerts,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsGrid(activeBusesCount),
              const SizedBox(height: 28),
              _buildSectionHeader("ACTIVE LIVE BUSES", Icons.sensors_rounded, AppColors.liveStatus),
              const SizedBox(height: 12),
              _buildActiveBusesList(liveBuses),
              const SizedBox(height: 28),
              _buildSectionHeader("EMERGENCY SOS LOGS", Icons.warning_amber_rounded, Colors.red),
              const SizedBox(height: 12),
              _buildEmergencyAlerts(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.pushNamed(context, AppRoutes.addSchedule),
        icon: const Icon(Icons.calendar_month_rounded),
        label: Text("View Schedules", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStatsGrid(int activeBuses) {
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
          icon: Icons.alt_route_rounded,
          label: "Active Routes",
          value: "14",
          color: AppColors.primaryNavy,
        ),
        _StatCard(
          icon: Icons.schedule_rounded,
          label: "Dispatch Slots",
          value: "38",
          color: AppColors.boysSpecial,
        ),
        _StatCard(
          icon: Icons.warning_rounded,
          label: "SOS Alerts",
          value: "${_sosAlerts.length}",
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: AppColors.primaryNavy,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveBusesList(Map<String, dynamic> liveBuses) {
    if (liveBuses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            "No buses currently active on route",
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: liveBuses.entries.map((entry) {
        final busNum = entry.key;
        final data = entry.value as Map<String, dynamic>;
        final from = data['fromHub'] ?? data['from'] ?? 'Abbasia Campus';
        final to = data['toHub'] ?? data['to'] ?? 'Baghdad Campus';

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
                    Text("$from ➔ $to", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
                    Text("Status: ${data['crowdStatus'] ?? 'Live'}", style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
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
  }

  Widget _buildEmergencyAlerts() {
    if (_sosAlerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            "No active emergency alerts",
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: _sosAlerts.map((row) {
        final msg = row['message'] ?? 'SOS Alert';
        final status = row['status'] ?? 'active';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_rounded, color: Colors.red, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(msg, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                    Text("Status: ${status.toString().toUpperCase()}", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade700)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
              Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }
}
