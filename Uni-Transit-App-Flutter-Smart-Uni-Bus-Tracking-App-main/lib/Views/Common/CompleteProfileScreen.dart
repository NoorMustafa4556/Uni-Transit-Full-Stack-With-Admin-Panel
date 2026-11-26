import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:uni_transit/Core/Util/CloudFirestoreCompat.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../Core/Constants/AppColors.dart';
import '../../ViewModels/AuthProvider.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:uni_transit/Widgets/CustomAppBar.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _rollNoController = TextEditingController();
  final _regNoController = TextEditingController();
  final _phoneController = TextEditingController();
  
  String? _selectedDepartment;
  String? _selectedSemester;
  File? _profileImage;
  bool _isLoading = false;
  bool _initialized = false;

  String _initialCountryCode = 'PK';
  String _initialPhoneNumber = '';

  final List<String> _departments = [
    'BS Computer Science',
    'BS Software Engineering',
    'BS Information Technology',
    'BS Electrical Engineering',
    'BS Mechanical Engineering',
    'BS Civil Engineering',
    'BBA (Business Administration)',
    'BS Mathematics',
    'BS Physics',
    'BS Chemistry',
    'Other'
  ];

  final List<String> _semesters = [
    '1st Semester',
    '2nd Semester',
    '3rd Semester',
    '4th Semester',
    '5th Semester',
    '6th Semester',
    '7th Semester',
    '8th Semester',
  ];

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadProfileImage() async {
    if (_profileImage == null) return null;
    
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return null;

      final client = Supabase.instance.client;
      final fileExtension = path.extension(_profileImage!.path);
      final fileName = '${user.id}$fileExtension';
      
      await client.storage.from('profile_images').upload(
        fileName,
        _profileImage!,
        fileOptions: const FileOptions(upsert: true),
      );
      
      return client.storage.from('profile_images').getPublicUrl(fileName);
    } catch (e) {
      _showError("Failed to upload image: $e");
      return null;
    }
  }

  void _submitProfile() async {
    final rollNo = _rollNoController.text.trim();
    final regNo = _regNoController.text.trim();
    final phone = _phoneController.text.trim();

    final existingProfile = ref.read(userProfileProvider).value;
    final String? existingImageUrl = existingProfile?['profileImage'] ?? existingProfile?['profileImageUrl'];

    // Profile picture validation removed to make it optional
    if (rollNo.isEmpty) {
      _showError("Roll Number is required");
      return;
    }
    if (regNo.isEmpty) {
      _showError("Registration Number is required");
      return;
    }
    if (_selectedDepartment == null) {
      _showError("Please select a department");
      return;
    }
    if (_selectedSemester == null) {
      _showError("Please select a semester");
      return;
    }
    if (phone.isEmpty) {
      _showError("Phone Number is required");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final imageUrl = _profileImage != null ? await _uploadProfileImage() : existingImageUrl;

      await ref.read(authStateProvider.notifier).updateProfile(
        profileImageUrl: imageUrl,
        rollNo: rollNo,
        regNo: regNo,
        department: _selectedDepartment,
        semester: _selectedSemester,
        phone: phone,
      );

      if (!mounted) return;

      // Force refresh userProfileProvider to update UI immediately
      ref.invalidate(userProfileProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Profile updated successfully!", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.primaryNavy,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      
      final canPop = Navigator.canPop(context);
      if (canPop) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(context, '/student_dashboard');
      }
    } catch (e) {
      if (mounted) {
        _showError("An error occurred. Please try again.");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);
    
    // Extract existing image url
    String? existingImageUrl;
    userProfileAsync.whenData((data) {
      if (data != null) {
        existingImageUrl = data['profileImage'] ?? data['profile_image'] ?? data['profileImageUrl'];
        if (!_initialized) {
          _rollNoController.text = data['rollNo'] ?? data['roll_no'] ?? '';
          _regNoController.text = data['regNo'] ?? data['reg_no'] ?? '';
          
          final phoneVal = data['phone'] ?? '';
          _phoneController.text = phoneVal;
          if (phoneVal.startsWith('+92')) {
            _initialCountryCode = 'PK';
            _initialPhoneNumber = phoneVal.substring(3);
          } else if (phoneVal.startsWith('03')) {
            _initialCountryCode = 'PK';
            _initialPhoneNumber = phoneVal.substring(1);
          } else {
            _initialCountryCode = 'PK';
            _initialPhoneNumber = phoneVal;
          }
          
          final dept = data['department'];
          if (dept != null && _departments.contains(dept)) {
            _selectedDepartment = dept;
          } else if (dept != null && dept.toString().isNotEmpty) {
            _departments.add(dept.toString());
            _selectedDepartment = dept.toString();
          }

          final sem = data['semester'];
          if (sem != null && _semesters.contains(sem)) {
            _selectedSemester = sem;
          } else if (sem != null && sem.toString().isNotEmpty) {
            _semesters.add(sem.toString());
            _selectedSemester = sem.toString();
          }
          
          _initialized = true;
        }
      }
    });

    final isEditing = _initialized && (_rollNoController.text.isNotEmpty || existingImageUrl != null);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: isEditing ? "EDIT PROFILE" : "COMPLETE PROFILE",
        showBackArrow: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Heading Intro
                         Text(
                          isEditing ? "Update Your Profile" : "Let's Get Started",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textDark,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isEditing 
                              ? "Keep your academic and transport profile details updated." 
                              : "Complete these details to verify your transit account.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Profile Avatar Card with camera badge
                        Center(
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: isDark ? AppColors.primaryYellow.withValues(alpha: 0.3) : AppColors.primaryNavy.withValues(alpha: 0.15), width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 54,
                                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  backgroundImage: _profileImage != null 
                                      ? FileImage(_profileImage!) 
                                      : (existingImageUrl != null && existingImageUrl!.isNotEmpty 
                                          ? NetworkImage(existingImageUrl!) 
                                          : null) as ImageProvider?,
                                  child: (_profileImage == null && (existingImageUrl == null || existingImageUrl!.isEmpty))
                                      ? const Icon(Icons.person_rounded, size: 55, color: AppColors.textSecondary)
                                      : null,
                                ),
                              ),
                              GestureDetector(
                                onTap: _isLoading ? null : _pickImage,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryYellow,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                                    ],
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, size: 20, color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 36),
                        
                        // Academic Details Section Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Theme.of(context).dividerColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.015),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 3,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.primaryYellow : AppColors.primaryNavy,
                                      borderRadius: BorderRadius.circular(1.5),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "ACADEMIC DETAILS",
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white60 : AppColors.textSecondary,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              
                              _buildTextField(
                                controller: _rollNoController,
                                label: "Roll Number / ID*",
                                icon: Icons.badge_outlined,
                              ),
                              const SizedBox(height: 16),
                              
                              _buildTextField(
                                controller: _regNoController,
                                label: "Registration Number*",
                                icon: Icons.app_registration_outlined,
                              ),
                              const SizedBox(height: 16),
                              
                              // Department Dropdown
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _selectedDepartment,
                                decoration: InputDecoration(
                                  labelText: "Program / Department*",
                                  labelStyle: GoogleFonts.poppins(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                                  prefixIcon: Icon(Icons.school_outlined, color: isDark ? AppColors.primaryYellow : AppColors.primaryNavy, size: 20),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: isDark ? Colors.white10 : AppColors.borderLight),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: isDark ? AppColors.primaryYellow : AppColors.primaryNavy, width: 1.5),
                                  ),
                                ),
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                style: GoogleFonts.poppins(color: isDark ? Colors.white : AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w500),
                                items: _departments.map((dept) {
                                  return DropdownMenuItem(
                                    value: dept, 
                                    child: Text(
                                      dept, 
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedDepartment = val;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),

                              // Semester Dropdown
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _selectedSemester,
                                decoration: InputDecoration(
                                  labelText: "Semester*",
                                  labelStyle: GoogleFonts.poppins(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                                  prefixIcon: Icon(Icons.layers_outlined, color: isDark ? AppColors.primaryYellow : AppColors.primaryNavy, size: 20),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: isDark ? Colors.white10 : AppColors.borderLight),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: isDark ? AppColors.primaryYellow : AppColors.primaryNavy, width: 1.5),
                                  ),
                                ),
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                style: GoogleFonts.poppins(color: isDark ? Colors.white : AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w500),
                                items: _semesters.map((sem) {
                                  return DropdownMenuItem(value: sem, child: Text(sem));
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedSemester = val;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Communication Details Section Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Theme.of(context).dividerColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.015),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 3,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.primaryYellow : AppColors.primaryNavy,
                                      borderRadius: BorderRadius.circular(1.5),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "COMMUNICATION DETAILS",
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white60 : AppColors.textSecondary,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              IntlPhoneField(
                                keyboardType: TextInputType.phone,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                initialCountryCode: _initialCountryCode,
                                initialValue: _initialPhoneNumber,
                                style: GoogleFonts.poppins(color: isDark ? Colors.white : AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w500),
                                decoration: InputDecoration(
                                  labelText: 'Phone Number*',
                                  labelStyle: GoogleFonts.poppins(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                                  prefixIcon: Icon(Icons.phone_outlined, color: isDark ? AppColors.primaryYellow : AppColors.primaryNavy, size: 20),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: isDark ? Colors.white10 : AppColors.borderLight),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: isDark ? AppColors.primaryYellow : AppColors.primaryNavy, width: 1.5),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: isDark ? Colors.white10 : AppColors.borderLight),
                                  ),
                                ),
                                onChanged: (phone) {
                                  _phoneController.text = phone.completeNumber;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        
                        // Action Button
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryNavy,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                              shadowColor: AppColors.primaryNavy.withValues(alpha: 0.3),
                            ),
                            child: _isLoading 
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : Text(
                                    isEditing ? "SAVE CHANGES" : "SAVE DETAILS", 
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(color: isDark ? Colors.white : AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, color: isDark ? AppColors.primaryYellow : AppColors.primaryNavy, size: 20),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? Colors.white10 : AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? AppColors.primaryYellow : AppColors.primaryNavy, width: 1.5),
        ),
      ),
    );
  }
}
