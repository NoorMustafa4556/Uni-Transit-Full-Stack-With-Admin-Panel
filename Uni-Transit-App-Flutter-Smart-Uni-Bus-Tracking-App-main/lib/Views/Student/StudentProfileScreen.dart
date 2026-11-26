import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uni_transit/Core/Constants/AppColors.dart';
import 'package:uni_transit/ViewModels/AuthProvider.dart';
import 'package:uni_transit/ViewModels/ThemeProvider.dart';
import 'package:uni_transit/Core/Routes/AppRoutes.dart';
import 'package:uni_transit/Widgets/CustomAppBar.dart';

class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider);
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: "STUDENT PROFILE",
        showBackArrow: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 24),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.completeProfile),
          ),
        ],
      ),
      body: SafeArea(
        child: user == null
            ? const Center(child: Text("Not Logged In", style: TextStyle(color: AppColors.textDark)))
            : userProfile.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy)),
                error: (err, stack) => Center(child: Text("Error: $err", style: const TextStyle(color: AppColors.error))),
                data: (data) {
                  if (data == null) return const Center(child: Text("No Profile Found", style: TextStyle(color: AppColors.textDark)));

                  final name = data['name'] ?? "Welcome Student";
                  final email = user.email ?? "user@iub.edu.pk";
                  final rollNo = data['rollNo'] ?? data['roll_no'] ?? "N/A";
                  final dept = data['department'] ?? "N/A";
                  final profileUrl = data['profileImage'] ?? data['profile_image'] ?? data['profileImageUrl'] ?? "";

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _buildCustomHeader(context, name, profileUrl),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader("ACADEMIC IDENTITY", context),
                              _buildInfoTile(
                                icon: Icons.school_rounded,
                                label: "University Department",
                                value: dept,
                                context: context,
                              ),
                              _buildInfoTile(
                                icon: Icons.badge_rounded,
                                label: "Roll Number / ID",
                                value: rollNo,
                                context: context,
                              ),
                              _buildInfoTile(
                                icon: Icons.assignment_ind_rounded,
                                label: "Registration Number",
                                value: data['regNo'] ?? data['reg_no'] ?? "N/A",
                                context: context,
                              ),
                              
                              const SizedBox(height: 32),
                              _buildSectionHeader("COMMUNICATION", context),
                              _buildInfoTile(
                                icon: Icons.email_rounded,
                                label: "Academic Email",
                                value: email,
                                context: context,
                              ),
                              _buildInfoTile(
                                icon: Icons.phone_android_rounded,
                                label: "Phone Number",
                                value: data['phone'] ?? "Not Provided",
                                context: context,
                              ),

                              const SizedBox(height: 24),
                              _buildSectionHeader("APP SETTINGS", context),
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Theme.of(context).dividerColor),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryNavy.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(15),
                                            ),
                                            child: const Icon(Icons.dark_mode_rounded, color: AppColors.primaryNavy, size: 22),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "Dark Mode",
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.textDark,
                                                  ),
                                                ),
                                                Text(
                                                  "Toggle app dark theme",
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: ref.watch(themeProvider) == ThemeMode.dark,
                                      onChanged: (isDark) {
                                        ref.read(themeProvider.notifier).toggleTheme(isDark);
                                      },
                                      activeColor: AppColors.primaryYellow,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 40),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryNavy,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 2,
                                    shadowColor: AppColors.primaryNavy.withValues(alpha: 0.3),
                                  ),
                                  child: Text(
                                    "RETURN TO DASHBOARD",
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildCustomHeader(BuildContext context, String name, String profileUrl) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryNavy.withValues(alpha: 0.2), width: 2),
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.05),
                  backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                  child: profileUrl.isEmpty
                      ? const Icon(Icons.person, color: AppColors.textSecondary, size: 60) 
                      : null,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: AppColors.primaryYellow, shape: BoxShape.circle),
                child: const Icon(Icons.verified_rounded, size: 20, color: Colors.black),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textDark,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.primaryYellow.withValues(alpha: 0.1) : AppColors.primaryNavy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.primaryYellow.withValues(alpha: 0.3) : AppColors.primaryNavy.withValues(alpha: 0.15)),
            ),
            child: Text(
              "IUB ENROLLED STUDENT",
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.primaryYellow : AppColors.primaryNavy,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, left: 4),
      child: Row(
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
              color: isDark ? Colors.white70 : AppColors.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({required IconData icon, required String label, required String value, required BuildContext context}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? AppColors.primaryYellow.withValues(alpha: 0.1) 
                  : AppColors.primaryNavy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon, 
              color: Theme.of(context).brightness == Brightness.dark 
                  ? AppColors.primaryYellow 
                  : AppColors.primaryNavy, 
              size: 22,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10, 
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppColors.textSecondary, 
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
