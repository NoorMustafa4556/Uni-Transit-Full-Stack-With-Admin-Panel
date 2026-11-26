import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uni_transit/Core/Constants/AppColors.dart';
import 'package:uni_transit/Core/Constants/AppAssets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ViewModels/AuthProvider.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _obscurePassword = true;

  void _signUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty) {
      _showError("Full name is compulsory");
      return;
    }
    if (email.isEmpty) {
      _showError("Email address is compulsory");
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showError("Please enter a valid university email");
      return;
    }
    if (password.isEmpty) {
      _showError("Password is compulsory");
      return;
    }
    if (password.length < 6) {
      _showError("Password must be at least 6 characters");
      return;
    }

    // Role is hardcoded to Student for safety. Drivers are added by Admin/Backend.
    const String studentRole = 'Student';

    await ref.read(authStateProvider.notifier).signUp(
      email: email,
      password: password,
      name: name,
      role: studentRole,
    );

    final authState = ref.read(authStateProvider);
    if (authState.hasError) {
      if (mounted) {
        _showError(_parseError(authState.error));
      }
    } else if (authState.hasValue && authState.value != null) {
      if (!mounted) return;
      
      // Navigate to Complete Profile Screen as requested
      Navigator.pushReplacementNamed(context, '/complete_profile');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _parseError(Object? error) {
    final msg = error?.toString() ?? '';
    if (msg.contains('Failed host lookup') ||
        msg.contains('SocketException') ||
        msg.contains('No address associated') ||
        msg.contains('Connection refused') ||
        msg.contains('Network is unreachable')) {
      return '📡 No internet connection. Please check your WiFi or mobile data and try again.';
    }
    if (msg.contains('AuthRetryableFetchException') ||
        msg.contains('statusCode: null')) {
      return '⚠️ Server unreachable. Please check your internet and try again.';
    }
    if (msg.contains('User already registered') ||
        msg.contains('already been registered')) {
      return '⚠️ This email is already registered. Please login instead.';
    }
    if (msg.contains('Password should be at least')) {
      return '🔒 Password must be at least 6 characters.';
    }
    if (msg.contains('invalid') && msg.contains('email')) {
      return '📧 Please enter a valid email address.';
    }
    if (msg.contains('rate limit') || msg.contains('Too many requests')) {
      return '⏳ Too many attempts. Please wait a moment and try again.';
    }
    return 'Signup failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primaryNavy, Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        height: 120,
                        width: 120,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            AppAssets.iubLogo,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Join UniTransit",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    _buildTextField(
                      controller: _nameController,
                      label: "Full Name",
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _emailController,
                      label: "University Email",
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _passwordController,
                      label: "Password",
                      icon: Icons.lock_outline,
                      isPassword: true,
                      obscureText: _obscurePassword,
                      togglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    SizedBox(
                      height: 55,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _signUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryYellow,
                          foregroundColor: AppColors.primaryNavy,
                        ),
                        child: isLoading 
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                "SIGN UP",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Already have an account? ",
                          style: TextStyle(color: Colors.white70),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "LOGIN",
                            style: TextStyle(
                              color: AppColors.primaryYellow,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? togglePassword,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: AppColors.primaryYellow),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white70,
                ),
                onPressed: togglePassword,
              )
            : null,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.primaryYellow),
        ),
      ),
    );
  }
}
