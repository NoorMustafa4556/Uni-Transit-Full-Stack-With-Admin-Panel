import 'package:flutter/material.dart';
import 'package:unitransit_admin/Core/Constants/AppColors.dart';
import 'package:unitransit_admin/Core/Network/ApiClient.dart';
import 'package:unitransit_admin/Core/Network/ApiConfig.dart';
import 'package:unitransit_admin/Core/Services/AdminApiService.dart';
import 'package:unitransit_admin/Core/Utils/ResponsiveUtil.dart';
import 'package:unitransit_admin/Core/Utils/Animations.dart';
import 'package:unitransit_admin/Models/TransportContactModel.dart';

class AppConfigScreen extends StatefulWidget {
  const AppConfigScreen({super.key});

  @override
  State<AppConfigScreen> createState() => _AppConfigScreenState();
}

class _AppConfigScreenState extends State<AppConfigScreen> {
  final _studentVersionController = TextEditingController();
  final _driverVersionController = TextEditingController();
  final _studentFocusNode = FocusNode();
  final _driverFocusNode = FocusNode();

  bool _studentMaintenance = false;
  bool _driverMaintenance = false;
  bool _isLoading = true;

  List<TransportContactModel> _contacts = [];

  @override
  void dispose() {
    _studentVersionController.dispose();
    _driverVersionController.dispose();
    _studentFocusNode.dispose();
    _driverFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _loadContacts();
  }

  Future<void> _loadConfig() async {
    try {
      final res = await ApiClient().get(
        ApiConfig.config,
        queryParameters: {'key': 'config'},
      );
      if (res.statusCode == 200 && res.data is Map) {
        final val = res.data['value_json'];
        final data = val is Map ? Map<String, dynamic>.from(val) : {};
        setState(() {
          _studentVersionController.text = data['studentAppVersion'] ?? '2.0.0';
          _driverVersionController.text = data['driverAppVersion'] ?? '2.0.0';
          _studentMaintenance = data['studentMaintenance'] ?? false;
          _driverMaintenance = data['driverMaintenance'] ?? false;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadContacts() async {
    try {
      final list = await AdminApiService().fetchContacts();
      setState(() {
        _contacts = list;
      });
    } catch (_) {}
  }

  Future<void> _saveConfig() async {
    await ApiClient().post(ApiConfig.config, data: {
      'key': 'config',
      'value_json': {
        'studentAppVersion': _studentVersionController.text,
        'driverAppVersion': _driverVersionController.text,
        'studentMaintenance': _studentMaintenance,
        'driverMaintenance': _driverMaintenance,
        'updatedAt': DateTime.now().toIso8601String(),
      },
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuration updated successfully!'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _updateMaintenance(String field, bool value) async {
    setState(() {
      if (field == 'studentMaintenance') _studentMaintenance = value;
      if (field == 'driverMaintenance') _driverMaintenance = value;
    });
    await _saveConfig();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = AppResponsiveUtil.isMobile(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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
              child: ListView(
                children: [
                  _buildSection('Student App Control', [
                    _buildTextField('Current Version', _studentVersionController, _studentFocusNode),
                    _buildSwitchTile('Maintenance Mode', _studentMaintenance, (v) => _updateMaintenance('studentMaintenance', v)),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Driver App Control', [
                    _buildTextField('Current Version', _driverVersionController, _driverFocusNode),
                    _buildSwitchTile('Maintenance Mode', _driverMaintenance, (v) => _updateMaintenance('driverMaintenance', v)),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Transport Helplines & Emergency Contacts', [
                    _buildContactsList(),
                  ]),
                  const SizedBox(height: 36),
                  Center(
                    child: SizedBox(
                      width: 200,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveConfig,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryNavy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildContactsList() {
    if (_contacts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Official Helpline: 0300-6809094 (Transport Officer, Baghdad-ul-Jadeed Campus)'),
      );
    }

    return Column(
      children: _contacts.map((c) {
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: c.isEmergency ? Colors.red.shade100 : Colors.blue.shade100,
            child: Icon(c.isEmergency ? Icons.emergency : Icons.phone, color: c.isEmergency ? Colors.red : Colors.blue),
          ),
          title: Text(c.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text('${c.phone} ${c.role != null ? "• ${c.role}" : ""}'),
          trailing: c.isEmergency
              ? const Chip(label: Text('24/7 SOS', style: TextStyle(fontSize: 10, color: Colors.white)), backgroundColor: Colors.red)
              : null,
        );
      }).toList(),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'App Configuration',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
                fontSize: AppResponsiveUtil.isMobile(context) ? 24 : null,
              ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Manage app version requirements, maintenance mode, and emergency transport contacts.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, FocusNode focusNode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: AppColors.backgroundLight,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(value ? 'Service is temporarily offline for maintenance' : 'Operating normally'),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.amber.shade800,
    );
  }
}
