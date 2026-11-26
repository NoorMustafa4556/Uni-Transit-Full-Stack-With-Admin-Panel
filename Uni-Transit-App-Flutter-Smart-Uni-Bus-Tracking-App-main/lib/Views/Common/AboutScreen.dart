import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uni_transit/Core/Constants/AppColors.dart';
import 'package:uni_transit/Core/Constants/AppAssets.dart';
import 'package:uni_transit/ViewModels/AppInfoProvider.dart';
import 'package:uni_transit/Widgets/CustomAppBar.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appInfoAsync = ref.watch(appInfoProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const CustomAppBar(
        title: "ABOUT APP",
        showBackArrow: true,
      ),
      body: SafeArea(
        child: appInfoAsync.when(
          data: (appInfo) => SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 30),
                
                // Brand Section
                Center(
                  child: Hero(
                    tag: 'app_logo',
                    child: Container(
                      width: 130,
                      height: 130,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black54 : AppColors.primaryNavy.withValues(alpha: 0.1),
                            blurRadius: 30,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: ClipOval(
                        child: appInfo.appLogoUrl.isNotEmpty 
                          ? Image.network(
                              appInfo.appLogoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Image.asset(AppAssets.iubLogo, fit: BoxFit.cover),
                            )
                          : Image.asset(AppAssets.iubLogo, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  (appInfo.appName ?? "UniTransit").isEmpty ? "UniTransit" : appInfo.appName, 
                  style: GoogleFonts.poppins(
                    fontSize: 32, 
                    fontWeight: FontWeight.w900, 
                    color: isDark ? Colors.white : AppColors.textDark, 
                    letterSpacing: 2
                  )
                ),
                const SizedBox(height: 4),
                Text(
                  (appInfo.appTagline ?? "Smart University Transport System").isEmpty ? "Smart University Transport System" : appInfo.appTagline, 
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12, 
                    color: isDark ? AppColors.primaryYellow : AppColors.primaryNavy, 
                    fontWeight: FontWeight.w700, 
                    letterSpacing: 1.5
                  )
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.primaryYellow.withValues(alpha: 0.1) : AppColors.primaryNavy.withValues(alpha: 0.08), 
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? AppColors.primaryYellow.withValues(alpha: 0.3) : AppColors.primaryNavy.withValues(alpha: 0.15)),
                  ),
                  child: Text(
                    appInfo.version.isEmpty ? "Version 1.2.0 (Stable)" : "Version ${appInfo.version}", 
                    style: GoogleFonts.poppins(
                      fontSize: 11, 
                      fontWeight: FontWeight.w700, 
                      color: isDark ? AppColors.primaryYellow : AppColors.primaryNavy
                    )
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Project Details Section
                _buildDetailSection(
                  context: context,
                  title: appInfo.visionHeader.isEmpty ? "PROJECT VISION" : appInfo.visionHeader.toUpperCase(),
                  content: appInfo.vision.isEmpty 
                    ? "UniTransit is a state-of-the-art solution designed for The Islamia University of Bahawalpur to digitize the bus tracking experience. It leverages real-time GPS data, Firebase synchronization, and smart routing algorithms to ensure students never miss their commute."
                    : appInfo.vision,
                ),
                
                const SizedBox(height: 24),
                
                // Contributors Section
                _buildDetailSection(
                  context: context,
                  title: "CONTRIBUTORS",
                  isList: true,
                  items: appInfo.contributors.isEmpty ? [
                    {"role": "Lead Developer", "name": "Noor Mustafa", "subtitle": "Roll No: F22BDOCS1M01160"},
                    {"role": "Supervisor", "name": "Dr. Umar Farooq Shafi", "subtitle": "Department of Computer Science"},
                  ] : appInfo.contributors.map((c) => {
                    "role": c.role,
                    "name": c.name,
                    "subtitle": c.subtitle,
                  }).toList(),
                ),
                
                const SizedBox(height: 60),
                
                // IUB Branding
                Column(
                  children: [
                    Text(
                      appInfo.university.isEmpty ? "THE ISLAMIA UNIVERSITY OF BAHAWALPUR" : appInfo.university.toUpperCase(), 
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 10, 
                        fontWeight: FontWeight.w800, 
                        color: isDark ? Colors.white54 : AppColors.textSecondary.withValues(alpha: 0.7), 
                        letterSpacing: 1.5
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy)),
          error: (err, stack) => Center(child: Text("Error loading info", style: TextStyle(color: isDark ? Colors.white : AppColors.textDark))),
        ),
      ),
    );
  }

  Widget _buildDetailSection({required BuildContext context, required String title, String? content, bool isList = false, List<Map<String, dynamic>>? items}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.primaryYellow : AppColors.primaryNavy,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title, 
                style: GoogleFonts.poppins(
                  fontSize: 12, 
                  fontWeight: FontWeight.w800, 
                  color: isDark ? AppColors.primaryYellow : AppColors.primaryNavy, 
                  letterSpacing: 1.5
                )
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!isList && content != null)
            Text(
              content, 
              textAlign: TextAlign.justify, 
              style: GoogleFonts.poppins(
                fontSize: 14, 
                height: 1.7, 
                color: isDark ? Colors.white70 : AppColors.textDark
              )
            )
          else if (isList && items != null)
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['role']!, 
                    style: GoogleFonts.poppins(
                      fontSize: 10, 
                      color: isDark ? Colors.white54 : AppColors.textSecondary, 
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5
                    )
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['name']!, 
                    style: GoogleFonts.poppins(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold, 
                      color: isDark ? Colors.white : AppColors.textDark
                    )
                  ),
                  if (item['subtitle'] != null)
                    Text(
                      item['subtitle']!, 
                      style: GoogleFonts.poppins(
                        fontSize: 12, 
                        color: isDark ? Colors.white38 : AppColors.textSecondary
                      )
                    ),
                ],
              ),
            )).toList(),
        ],
      ),
    );
  }
}
