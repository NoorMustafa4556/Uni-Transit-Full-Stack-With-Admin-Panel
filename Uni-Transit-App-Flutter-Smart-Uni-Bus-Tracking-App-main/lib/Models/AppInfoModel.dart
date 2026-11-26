class AppInfoModel {
  final String appName;
  final String appTagline;
  final String visionHeader;
  final String vision;
  final String version;
  final String university;
  final String appLogoUrl;
  
  // Design System
  final String primaryColor;
  final String accentColor;
  final String backgroundColor;
  final String cardColor;
  final String textPrimaryColor;
  final String textSecondaryColor;

  final List<ContributorModel> contributors;

  AppInfoModel({
    required this.appName,
    required this.appTagline,
    required this.visionHeader,
    required this.vision,
    required this.version,
    required this.university,
    required this.appLogoUrl,
    required this.primaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.cardColor,
    required this.textPrimaryColor,
    required this.textSecondaryColor,
    required this.contributors,
  });

  factory AppInfoModel.fromMap(Map<String, dynamic> data) {
    return AppInfoModel(
      appName: data['appName'] ?? data['app_name'] ?? 'UniTransit',
      appTagline: data['appTagline'] ?? data['app_tagline'] ?? 'Smart University Transport System',
      visionHeader: data['visionHeader'] ?? data['vision_header'] ?? 'PROJECT VISION',
      vision: data['vision'] ?? '',
      version: data['version'] ?? '1.0.0',
      university: data['university'] ?? 'The Islamia University of Bahawalpur',
      appLogoUrl: data['appLogoUrl'] ?? data['app_logo_url'] ?? '',
      
      primaryColor: data['primaryColor'] ?? data['primary_color'] ?? '#1A237E',
      accentColor: data['accentColor'] ?? data['accent_color'] ?? '#FFC107',
      backgroundColor: data['backgroundColor'] ?? data['background_color'] ?? '#F8FAFC',
      cardColor: data['cardColor'] ?? data['card_color'] ?? '#FFFFFF',
      textPrimaryColor: data['textPrimaryColor'] ?? data['text_primary_color'] ?? '#0F172A',
      textSecondaryColor: data['textSecondaryColor'] ?? data['text_secondary_color'] ?? '#64748B',
      
      contributors: (data['contributors'] as List? ?? [])
          .map((item) => ContributorModel.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'appName': appName,
      'appTagline': appTagline,
      'visionHeader': visionHeader,
      'vision': vision,
      'version': version,
      'university': university,
      'appLogoUrl': appLogoUrl,
      'primaryColor': primaryColor,
      'accentColor': accentColor,
      'backgroundColor': backgroundColor,
      'cardColor': cardColor,
      'textPrimaryColor': textPrimaryColor,
      'textSecondaryColor': textSecondaryColor,
      'contributors': contributors.map((c) => c.toMap()).toList(),
    };
  }
}

class ContributorModel {
  final String name;
  final String role;
  final String subtitle;

  ContributorModel({required this.name, required this.role, required this.subtitle});

  factory ContributorModel.fromMap(Map<String, dynamic> map) {
    return ContributorModel(
      name: map['name'] ?? '',
      role: map['role'] ?? '',
      subtitle: map['subtitle'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'role': role, 'subtitle': subtitle};
}
