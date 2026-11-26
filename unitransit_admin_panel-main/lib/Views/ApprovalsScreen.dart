import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:unitransit_admin/Core/Constants/AppColors.dart';
import 'package:unitransit_admin/Core/Services/AdminApiService.dart';
import 'package:unitransit_admin/Core/Utils/ResponsiveUtil.dart';
import 'package:unitransit_admin/Models/ChangeRequestModel.dart';
import 'package:unitransit_admin/ViewModels/LoginViewModel.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  final AdminApiService _apiService = AdminApiService();
  String _selectedStatus = 'pending_approval';
  bool _isLoading = false;
  List<ChangeRequestModel> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final list = await _apiService.fetchApprovals(status: _selectedStatus);
      setState(() {
        _requests = list;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = AppResponsiveUtil.isMobile(context);
    final loginVM = context.watch<LoginViewModel>();
    final isSuperAdmin = loginVM.isSuperAdmin;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isSuperAdmin),
          const SizedBox(height: 24),
          _buildFilterTabs(),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _requests.isEmpty
                    ? _buildEmptyState()
                    : _buildRequestsList(isSuperAdmin),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isSuperAdmin) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Higher Authority Approvals',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isSuperAdmin
                  ? 'Maker-Checker Governance Queue: Review, approve, or reject operational changes.'
                  : 'Sub-Admin Change Requests: Track status of your submitted operational changes.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
        IconButton(
          onPressed: _loadRequests,
          tooltip: 'Refresh Queue',
          icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryNavy),
        ),
      ],
    );
  }

  Widget _buildFilterTabs() {
    return Row(
      children: [
        _buildFilterChip('Pending', 'pending_approval', Colors.amber.shade800),
        const SizedBox(width: 12),
        _buildFilterChip('Approved', 'approved', Colors.green.shade700),
        const SizedBox(width: 12),
        _buildFilterChip('Rejected', 'rejected', Colors.red.shade700),
      ],
    );
  }

  Widget _buildFilterChip(String label, String status, Color activeColor) {
    final isSelected = _selectedStatus == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedStatus = status);
          _loadRequests();
        }
      },
      selectedColor: activeColor.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? activeColor : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildRequestsList(bool isSuperAdmin) {
    return ListView.builder(
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final req = _requests[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(req.status).withValues(alpha: 0.15),
              child: Icon(
                _getStatusIcon(req.status),
                color: _getStatusColor(req.status),
                size: 20,
              ),
            ),
            title: Text(
              '${req.action.toUpperCase()} on ${req.entityType.toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              'Submitted by: ${req.requestedByName} • ${DateFormat('dd MMM yyyy, hh:mm a').format(req.createdAt)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            childrenPadding: const EdgeInsets.all(20),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Proposed Payload Data:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    SelectableText(
                      const JsonEncoder.withIndent('  ').convert(req.payload),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                    if (req.reviewNote != null && req.reviewNote!.isNotEmpty) ...[
                      const Divider(height: 24),
                      Text(
                        'Reviewer Note (${req.reviewedByName ?? "Authority"}): ${req.reviewNote}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: req.status == 'approved' ? Colors.green.shade800 : Colors.red.shade800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (req.status == 'pending_approval')
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isSuperAdmin)
                      const Chip(
                        label: Text('Awaiting Super Admin Decision'),
                        backgroundColor: Colors.amber,
                        labelStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      )
                    else ...[
                      OutlinedButton.icon(
                        onPressed: () => _showReviewDialog(req, isApprove: false),
                        icon: const Icon(Icons.close_rounded, color: Colors.red),
                        label: const Text('Reject Request', style: TextStyle(color: Colors.red)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showReviewDialog(req, isApprove: true),
                        icon: const Icon(Icons.check_rounded, color: Colors.white),
                        label: const Text('Approve & Commit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  void _showReviewDialog(ChangeRequestModel req, {required bool isApprove}) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isApprove ? 'Approve Request' : 'Reject Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isApprove
                  ? 'Are you sure you want to approve this change? The operational mutation will be committed.'
                  : 'Specify reason for rejecting this change request.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                hintText: isApprove ? 'Optional approval note' : 'Mandatory rejection reason',
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              if (isApprove) {
                await _apiService.approveChangeRequest(req.id, reviewNote: noteController.text.trim());
              } else {
                await _apiService.rejectChangeRequest(req.id, reviewNote: noteController.text.trim());
              }
              _loadRequests();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isApprove ? Colors.green.shade700 : Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: Text(isApprove ? 'Confirm Approve' : 'Confirm Reject'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No $_selectedStatus change requests found',
            style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green.shade700;
      case 'rejected':
        return Colors.red.shade700;
      default:
        return Colors.amber.shade800;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.pending_rounded;
    }
  }
}
