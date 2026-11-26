import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uni_transit/Core/Network/ApiClient.dart';
import 'package:uni_transit/Core/Network/ApiConfig.dart';
import '../Models/AppInfoModel.dart';

// Default app info so the app never hangs
AppInfoModel _defaultAppInfo() => AppInfoModel(
      appName: 'Uni-Transit',
      appTagline: 'Smart University Transport System',
      visionHeader: 'PROJECT VISION',
      vision: 'Connecting students and drivers seamlessly across IUB campuses.',
      version: '2.0.0',
      university: 'The Islamia University of Bahawalpur',
      appLogoUrl: '',
      primaryColor: '#1A237E',
      accentColor: '#FFC107',
      backgroundColor: '#F8FAFC',
      cardColor: '#FFFFFF',
      textPrimaryColor: '#0F172A',
      textSecondaryColor: '#64748B',
      contributors: [
        ContributorModel(name: 'Noor Mustafa', role: 'Full Stack Engineer', subtitle: 'Lead Developer'),
      ],
    );

final appInfoProvider = FutureProvider<AppInfoModel>((ref) async {
  try {
    final response = await ApiClient().get(ApiConfig.config).timeout(const Duration(seconds: 4));
    if (response.statusCode == 200 && response.data != null) {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return AppInfoModel.fromMap(data);
      }
    }
  } catch (_) {}
  return _defaultAppInfo();
});
