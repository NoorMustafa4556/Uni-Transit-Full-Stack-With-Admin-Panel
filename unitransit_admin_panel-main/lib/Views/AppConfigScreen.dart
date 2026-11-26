import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unitransit_admin/Core/Constants/AppColors.dart';
import 'package:unitransit_admin/Core/Utils/ResponsiveUtil.dart';
import 'package:unitransit_admin/Core/Utils/Animations.dart';

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
  }

  Future<void> _loadConfig() async {
    try {
      final res = await Supabase.instance.client
          .from('app_settings')
          .select()
          .eq('key', 'config')
          .maybeSingle();
      if (res != null) {
        final data = (res['value'] as Map<String, dynamic>?) ?? {};
        setState(() {
          _studentVersionController.text = data['studentAppVersion'] ?? '1.0.0';
          _driverVersionController.text = data['driverAppVersion'] ?? '1.0.0';
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

  Future<void> _saveConfig() async {
    await Supabase.instance.client.from('app_settings').upsert({
      'key': 'config',
      'value': {
        'studentAppVersion': _studentVersionController.text,
        'driverAppVersion': _driverVersionController.text,
        'studentMaintenance': _studentMaintenance,
        'driverMaintenance': _driverMaintenance,
        'updatedAt': DateTime.now().toIso8601String(),
      },
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuration updated successfully!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = AppResponsiveUtil.isMobile(context);

    return FadeInSlide(
      duration: const Duration(milliseconds: 600),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: Supabase.instance.client
              .from('app_settings')
              .select().eq('key', 'config').asStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final row = snapshot.data?.firstWhere(
              (r) => r['key'] == 'config',
              orElse: () => {},
            );
            final data = (row?['value'] as Map<String, dynamic>?) ?? {};
            if (!_studentFocusNode.hasFocus) _studentVersionController.text = data['studentAppVersion'] ?? '1.0.0';
            if (!_driverFocusNode.hasFocus) _driverVersionController.text = data['driverAppVersion'] ?? '1.0.0';
            _studentMaintenance = data['studentMaintenance'] ?? _studentMaintenance;
            _driverMaintenance = data['driverMaintenance'] ?? _driverMaintenance;

            return Column(
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
                      const SizedBox(height: 48),
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
            );
          },
        ),
      ),
    );
  }

  Future<void> _updateMaintenance(String field, bool value) async {
    await Supabase.instance.client.from('app_settings').upsert({
      'key': 'config',
      'value': {field: value},
    });
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
              ),
        ),
        const Text('Manage app versions and system-wide maintenance modes.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryNavy)),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, FocusNode focusNode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          prefixIcon: const Icon(Icons.system_update_rounded),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String label, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: const Text('Prevent users from accessing the app during maintenance.'),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primaryNavy,
    );
  }
}

