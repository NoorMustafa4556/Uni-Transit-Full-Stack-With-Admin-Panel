import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../Models/AppInfoModel.dart';

// Default app info so the app never hangs if Supabase row is missing
AppInfoModel _defaultAppInfo() => AppInfoModel(
      appName: 'Uni-Transit',
      appTagline: 'Smart University Transport System',
      visionHeader: 'PROJECT VISION',
      vision: 'Connecting students and drivers seamlessly.',
      version: '1.0.0',
      university: 'University of Management & Technology',
      appLogoUrl: '',
      primaryColor: '#1A237E',
      accentColor: '#FFC107',
      backgroundColor: '#F8FAFC',
      cardColor: '#FFFFFF',
      textPrimaryColor: '#0F172A',
      textSecondaryColor: '#64748B',
      contributors: [],
    );

final appInfoProvider = FutureProvider<AppInfoModel>((ref) async {
  try {
    final res = await Supabase.instance.client
        .from('app_settings')
        .select()
        .eq('key', 'about')
        .maybeSingle()
        .timeout(const Duration(seconds: 5));

    if (res == null) return _defaultAppInfo();

    final data = (res['value'] as Map<String, dynamic>?) ?? {};
    return AppInfoModel(
      appName: data['appName'] ?? 'Uni-Transit',
      appTagline: data['appTagline'] ?? 'Smart University Transport System',
      visionHeader: data['visionHeader'] ?? 'PROJECT VISION',
      vision: data['vision'] ?? '',
      version: data['version'] ?? '1.0.0',
      university: data['university'] ?? '',
      appLogoUrl: data['appLogoUrl'] ?? '',
      primaryColor: data['primaryColor'] ?? '#1A237E',
      accentColor: data['accentColor'] ?? '#FFC107',
      backgroundColor: data['backgroundColor'] ?? '#F8FAFC',
      cardColor: data['cardColor'] ?? '#FFFFFF',
      textPrimaryColor: data['textPrimaryColor'] ?? '#0F172A',
      textSecondaryColor: data['textSecondaryColor'] ?? '#64748B',
      contributors: (data['contributors'] as List? ?? [])
          .map((item) => ContributorModel.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
    );
  } catch (_) {
    return _defaultAppInfo();
  }
});
