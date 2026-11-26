import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_transit/Core/Constants/AppColors.dart';

class SosReviewBottomSheet extends StatefulWidget {
  final String notificationId;
  final String alertId;
  final String alertMessage;

  const SosReviewBottomSheet({
    super.key,
    required this.notificationId,
    required this.alertId,
    required this.alertMessage,
  });

  @override
  State<SosReviewBottomSheet> createState() => _SosReviewBottomSheetState();
}

class _SosReviewBottomSheetState extends State<SosReviewBottomSheet> {
  int _rating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final client = Supabase.instance.client;
      // 1. Fetch user role (Student or Driver) from public.profiles
      final profile = await client.from('profiles').select().eq('id', user.id).maybeSingle();
      final String userRole = profile?['role'] ?? 'Student';
      final String displayName = profile?['name'] ?? user.email ?? 'Anonymous';

      // 2. Save review to Supabase
      try {
        await client.from('sos_reviews').insert({
          'alert_id': widget.alertId,
          'user_id': user.id,
          'user_name': displayName,
          'user_role': userRole,
          'rating': _rating,
          'review': _commentController.text.trim(),
          'alert_message': widget.alertMessage,
        });
      } catch (e) {
        debugPrint("SOS Review table insert failed: $e (This is fine if table does not exist)");
      }

      // 3. Mark notification as reviewed in notifications table
      await client.from('notifications').update({
        'is_reviewed': true,
      }).eq('id', widget.notificationId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error submitting SOS review: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Rate Emergency Help",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "An administrator resolved your SOS request. Please rate the assistance you received:",
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                final starVal = index + 1;
                return IconButton(
                  icon: Icon(
                    starVal <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber[600],
                    size: 40,
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = starVal;
                    });
                  },
                );
              }),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Tell us about your experience (optional)...",
              hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text("Submit Feedback", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
