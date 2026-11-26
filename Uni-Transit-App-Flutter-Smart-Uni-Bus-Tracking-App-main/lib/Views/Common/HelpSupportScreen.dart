import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uni_transit/Core/Constants/AppColors.dart';
import 'package:uni_transit/Core/Network/ApiClient.dart';
import 'package:uni_transit/Core/Network/ApiConfig.dart';
import 'package:uni_transit/Services/AuthService.dart';
import 'package:uni_transit/Widgets/CustomAppBar.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final ApiClient _api = ApiClient();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _faqs = [];
  List<Map<String, dynamic>> _tickets = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _activeTabIndex = 0; // 0 for Quick Help, 1 for Submit Ticket, 2 for My Tickets

  @override
  void initState() {
    super.initState();
    _loadData();
    _prefillUser();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _prefillUser() {
    final user = AuthService().currentUser;
    if (user != null) {
      if (user.phone != null) _phoneController.text = user.phone!;
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch contacts
      final contactsRes = await _api.get(ApiConfig.contacts);
      if (contactsRes.statusCode == 200 && contactsRes.data != null) {
        final List cList = contactsRes.data is List ? contactsRes.data : (contactsRes.data['results'] ?? []);
        _contacts = cList.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      // 2. Fetch FAQs
      final faqsRes = await _api.get(ApiConfig.faqs);
      if (faqsRes.statusCode == 200 && faqsRes.data != null) {
        final List fList = faqsRes.data is List ? faqsRes.data : (faqsRes.data['results'] ?? []);
        _faqs = fList.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      // 3. Fetch tickets
      final ticketsRes = await _api.get(ApiConfig.tickets);
      if (ticketsRes.statusCode == 200 && ticketsRes.data != null) {
        final List tList = ticketsRes.data is List ? ticketsRes.data : (ticketsRes.data['results'] ?? []);
        _tickets = tList.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}

    // Fallback emergency contacts if list is empty
    if (_contacts.isEmpty) {
      _contacts = [
        {
          "name": "IUB Transport Office Control Room",
          "phone": "0300-6809094",
          "whatsapp": "03006809094",
          "role": "Chief Transport Officer",
        },
        {
          "name": "Campus Security & Helpline",
          "phone": "062-9250235",
          "whatsapp": "",
          "role": "24/7 Security Dispatch",
        },
      ];
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _launchCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    String clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) {
      clean = '92${clean.substring(1)}';
    }
    final uri = Uri.parse('https://wa.me/$clean?text=Assalam-o-Alaikum,%20I%20need%20assistance%20regarding%20IUB%20Bus%20Service.');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _submitTicket() async {
    final subject = _subjectController.text.trim();
    final description = _descriptionController.text.trim();
    final phone = _phoneController.text.trim();

    if (subject.isEmpty) {
      _showToast("Please enter a subject", Colors.orange);
      return;
    }
    if (description.isEmpty) {
      _showToast("Please enter ticket description", Colors.orange);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final res = await _api.post(
        ApiConfig.tickets,
        data: {
          'subject': subject,
          'description': description,
          'contact_phone': phone,
        },
      );

      if (res.statusCode == 201 || res.statusCode == 200) {
        _showToast("Ticket submitted successfully!", Colors.green);
        _subjectController.clear();
        _descriptionController.clear();
        setState(() => _activeTabIndex = 2);
        _loadData();
      } else {
        _showToast("Failed to submit ticket", Colors.red);
      }
    } catch (e) {
      _showToast("Submission error: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showToast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: CustomAppBar(
        title: "Help & Support",
        showBackArrow: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy))
          : Column(
              children: [
                // Navigation Tabs
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _buildTabButton("Quick Help", 0),
                      const SizedBox(width: 8),
                      _buildTabButton("Submit Ticket", 1),
                      const SizedBox(width: 8),
                      _buildTabButton("My Tickets (${_tickets.length})", 2),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.borderLight),

                Expanded(
                  child: _activeTabIndex == 0
                      ? _buildQuickHelpView()
                      : (_activeTabIndex == 1 ? _buildSubmitTicketView() : _buildTicketHistoryView()),
                ),
              ],
            ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _activeTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryNavy : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickHelpView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Contact Cards Header
        Text(
          "IUB TRANSPORT HELPLINES",
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 0.8),
        ),
        const SizedBox(height: 10),

        for (final contact in _contacts) _buildContactCard(contact),

        const SizedBox(height: 24),
        Text(
          "FREQUENTLY ASKED QUESTIONS",
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 0.8),
        ),
        const SizedBox(height: 10),

        if (_faqs.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Text(
              "How to track buses?\nSelect your route or stop from the Dashboard. Live moving buses appear automatically.\n\nWhat are 'Last Bus' badges?\nWhen remaining buses in the slot drop to 0, the last running bus is flagged to warn students.",
              style: GoogleFonts.poppins(fontSize: 13, height: 1.5, color: const Color(0xFF334155)),
            ),
          )
        else
          for (final faq in _faqs)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                title: Text(faq['question'] ?? 'FAQ', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(faq['answer'] ?? '', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700, height: 1.4)),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _buildContactCard(Map<String, dynamic> contact) {
    final name = contact['name'] ?? 'Transport Support';
    final role = contact['role'] ?? 'Coordinator';
    final phone = contact['phone'] ?? '0300-6809094';
    final whatsapp = contact['whatsapp'] ?? contact['phone'] ?? '03006809094';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.support_agent_rounded, color: AppColors.primaryNavy, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                    Text(role, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Direct Call button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _launchCall(phone),
                  icon: const Icon(Icons.call_rounded, size: 16, color: Colors.white),
                  label: Text("Call $phone", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // WhatsApp Complaint button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _launchWhatsApp(whatsapp),
                  icon: const Icon(Icons.chat_bubble_rounded, size: 16, color: Colors.white),
                  label: Text("WhatsApp", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitTicketView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Submit Support Ticket", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
              const SizedBox(height: 6),
              Text("Have an issue with a bus, driver, or timing? Submit a ticket and our transport admin will address it.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 20),

              Text("Subject", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _subjectController,
                decoration: InputDecoration(
                  hintText: "e.g. Bus 12 skipped Saddar Pully stop",
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
              ),
              const SizedBox(height: 14),

              Text("Contact Phone", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: "0300-1234567",
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
              ),
              const SizedBox(height: 14),

              Text("Description", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "Provide details about date, time, bus number, and issue...",
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text("Submit Ticket", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTicketHistoryView() {
    if (_tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.confirmation_number_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text("No tickets submitted yet", style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tickets.length,
      itemBuilder: (context, index) {
        final ticket = _tickets[index];
        final status = (ticket['status'] ?? 'pending').toString().toLowerCase();
        Color statusColor = Colors.orange;
        if (status == 'resolved' || status == 'closed') statusColor = Colors.green;
        if (status == 'in_progress') statusColor = Colors.blue;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      ticket['subject'] ?? 'Support Ticket',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      status.toUpperCase(),
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                ticket['description'] ?? '',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
              ),
              if (ticket['admin_response'] != null && ticket['admin_response'].toString().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.reply_rounded, size: 16, color: AppColors.primaryNavy),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Admin: ${ticket['admin_response']}",
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF1E293B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
