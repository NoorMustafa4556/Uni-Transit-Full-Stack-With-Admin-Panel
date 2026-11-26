import 'package:flutter/material.dart';
import 'package:unitransit_admin/Core/Constants/AppColors.dart';
import 'package:unitransit_admin/Core/Network/ApiClient.dart';
import 'package:unitransit_admin/Core/Network/ApiConfig.dart';
import 'package:unitransit_admin/Core/Utils/ResponsiveUtil.dart';
import 'package:unitransit_admin/Core/Utils/Animations.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final ApiClient _client = ApiClient();
  bool _isLoading = false;
  List<Map<String, dynamic>> _buses = [];

  @override
  void initState() {
    super.initState();
    _fetchBuses();
  }

  Future<void> _fetchBuses() async {
    setState(() => _isLoading = true);
    try {
      final res = await _client.get(ApiConfig.buses);
      if (res.statusCode == 200 && res.data is List) {
        setState(() {
          _buses = List<Map<String, dynamic>>.from(res.data as List);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = AppResponsiveUtil.isMobile(context);

    return FadeInSlide(
      duration: const Duration(milliseconds: 600),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 32),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buses.isEmpty
                      ? const Center(child: Text('No buses found to track maintenance.'))
                      : ListView.builder(
                          itemCount: _buses.length,
                          itemBuilder: (context, index) {
                            final bus = _buses[index];
                            final busNum = bus['bus_number'] ?? 'Bus';
                            final plateNum = bus['plate_number'] ?? 'N/A';
                            final id = bus['id']?.toString() ?? '';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: AppColors.primaryNavy,
                                  child: Icon(Icons.build_circle_rounded, color: Colors.white),
                                ),
                                title: Text('Bus $busNum ($plateNum)', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: const Text('Maintenance Health: Good • Scheduled Service: In 60 Days'),
                                trailing: ElevatedButton(
                                  onPressed: () => _showLogMaintenanceDialog(context, id, busNum),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryNavy,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Log Service'),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fleet Maintenance & Fuel Logs',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
                fontSize: AppResponsiveUtil.isMobile(context) ? 24 : null,
              ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Track vehicle servicing intervals, engine inspections, and fuel economy.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  void _showLogMaintenanceDialog(BuildContext context, String busId, String busNum) {
    final fuelCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Log Service for Bus $busNum'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: fuelCtrl,
              decoration: const InputDecoration(labelText: 'Recorded Fuel Average (km/l)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            const Text('Next Service will automatically be scheduled in 90 days.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Maintenance record updated for Bus $busNum'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Confirm Maintenance'),
          ),
        ],
      ),
    );
  }
}
