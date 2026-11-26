import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uni_transit/Core/Constants/AppColors.dart';
import 'package:uni_transit/Core/Network/ApiClient.dart';
import 'package:uni_transit/Core/Network/ApiConfig.dart';

class TrackMyTrainSheet extends StatefulWidget {
  final int? tripId;
  final int? stopId;
  final String busNumber;
  final String? plateNumber;
  final String? gender;
  final String? crowdStatus;
  final List<String>? tags;
  final int? totalBuses;
  final int? dispatchedCount;
  final int? remainingCount;
  final bool isLastBus;
  final String? etaText;
  final String? distanceText;

  const TrackMyTrainSheet({
    super.key,
    this.tripId,
    this.stopId,
    required this.busNumber,
    this.plateNumber,
    this.gender = 'Combined',
    this.crowdStatus = 'seats_available',
    this.tags = const [],
    this.totalBuses = 1,
    this.dispatchedCount = 1,
    this.remainingCount = 0,
    this.isLastBus = false,
    this.etaText,
    this.distanceText,
  });

  static void show(
    BuildContext context, {
    int? tripId,
    int? stopId,
    required String busNumber,
    String? plateNumber,
    String? gender,
    String? crowdStatus,
    List<String>? tags,
    int? totalBuses,
    int? dispatchedCount,
    int? remainingCount,
    bool isLastBus = false,
    String? etaText,
    String? distanceText,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TrackMyTrainSheet(
        tripId: tripId,
        stopId: stopId,
        busNumber: busNumber,
        plateNumber: plateNumber,
        gender: gender,
        crowdStatus: crowdStatus,
        tags: tags,
        totalBuses: totalBuses,
        dispatchedCount: dispatchedCount,
        remainingCount: remainingCount,
        isLastBus: isLastBus,
        etaText: etaText,
        distanceText: distanceText,
      ),
    );
  }

  @override
  State<TrackMyTrainSheet> createState() => _TrackMyTrainSheetState();
}

class _TrackMyTrainSheetState extends State<TrackMyTrainSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _stops = [];

  @override
  void initState() {
    super.initState();
    _loadStopFeed();
  }

  Future<void> _loadStopFeed() async {
    try {
      final Map<String, dynamic> query = {};
      if (widget.tripId != null) query['trip_id'] = widget.tripId;
      if (widget.stopId != null) query['stop_id'] = widget.stopId;

      final res = await ApiClient().get(ApiConfig.studentStopFeed, queryParameters: query);
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data is Map<String, dynamic> ? res.data : <String, dynamic>{};
        final stopsList = data['stops'] as List? ?? [];
        if (mounted) {
          setState(() {
            _stops = stopsList.map((e) => Map<String, dynamic>.from(e)).toList();
            _isLoading = false;
          });
        }
        return;
      }
    } catch (_) {}

    // Fallback default stops if network unavailable
    if (mounted) {
      setState(() {
        _stops = [
          {"id": 1, "name": "Abbasia Campus", "status": "crossed", "time": "07:30 AM"},
          {"id": 2, "name": "One Uni Point", "status": "crossed", "time": "07:42 AM"},
          {"id": 3, "name": "Saddar Pully", "status": "current", "time": "Live Now"},
          {"id": 4, "name": "Dubai Chowk", "status": "upcoming", "time": "ETA 8 mins"},
          {"id": 5, "name": "Baghdad-ul-Jadeed", "status": "upcoming", "time": "ETA 18 mins"},
        ];
        _isLoading = false;
      });
    }
  }

  Color _getCrowdColor(String status) {
    switch (status.toLowerCase()) {
      case 'seats_available':
        return Colors.green;
      case 'standing':
        return Colors.orange;
      case 'full':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _getCrowdLabel(String status) {
    switch (status.toLowerCase()) {
      case 'seats_available':
        return 'Seats Available';
      case 'standing':
        return 'Standing Only';
      case 'full':
        return 'Bus Full';
      default:
        return 'Active';
    }
  }

  @override
  Widget build(BuildContext context) {
    final crowdColor = _getCrowdColor(widget.crowdStatus ?? 'seats_available');

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bus Icon badge
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryNavy.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.directions_bus_rounded, color: AppColors.primaryNavy, size: 30),
                ),
                const SizedBox(width: 14),
                // Bus details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.busNumber,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          if (widget.plateNumber != null && widget.plateNumber!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.plateNumber!,
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // Gender badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryYellow.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.gender ?? 'Combined',
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryNavy),
                            ),
                          ),
                          // Crowd badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: crowdColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(radius: 3, backgroundColor: crowdColor),
                                const SizedBox(width: 4),
                                Text(
                                  _getCrowdLabel(widget.crowdStatus ?? 'seats_available'),
                                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: crowdColor),
                                ),
                              ],
                            ),
                          ),
                          // Tags
                          for (final tag in widget.tags ?? [])
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.indigo.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tag,
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.indigo),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Slot Counter & Last Bus Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Dispatched: ${widget.dispatchedCount ?? 1}/${widget.totalBuses ?? 1}",
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                        ),
                        Text(
                          "${widget.remainingCount ?? 0} Remaining",
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.isLastBus) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(
                          "LAST BUS",
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ETA & Distance Info Box
          if (widget.etaText != null || widget.distanceText != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text("DISTANCE", style: GoogleFonts.poppins(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600)),
                        Text(widget.distanceText ?? "---", style: GoogleFonts.poppins(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(height: 24, width: 1, color: Colors.white24),
                    Column(
                      children: [
                        Text("ESTIMATED ARRIVAL", style: GoogleFonts.poppins(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600)),
                        Text(widget.etaText ?? "Live", style: GoogleFonts.poppins(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          const Divider(height: 16),

          // Section Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "ROUTE TIMELINE (LIVE TRACK-MY-TRAIN)",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),

          // Vertical Stops Timeline
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: _stops.length,
                    itemBuilder: (context, index) {
                      final stop = _stops[index];
                      final status = (stop['status'] ?? 'upcoming').toString().toLowerCase();
                      final isCrossed = status == 'crossed';
                      final isCurrent = status == 'current' || status == 'arrived';
                      final isStudentTarget = stop['is_target'] == true || (widget.stopId != null && stop['id'] == widget.stopId);

                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Timeline visual: Circle + Line
                            Column(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isCrossed
                                        ? Colors.green
                                        : (isCurrent ? const Color(0xFF2563EB) : Colors.white),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isCrossed
                                          ? Colors.green
                                          : (isCurrent ? const Color(0xFF2563EB) : Colors.grey.shade400),
                                      width: 2.5,
                                    ),
                                    boxShadow: isCurrent
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                                              blurRadius: 8,
                                              spreadRadius: 2,
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: isCrossed
                                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                                      : (isCurrent
                                          ? const Center(
                                              child: CircleAvatar(radius: 4, backgroundColor: Colors.white),
                                            )
                                          : null),
                                ),
                                if (index < _stops.length - 1)
                                  Expanded(
                                    child: Container(
                                      width: 2.5,
                                      color: isCrossed ? Colors.green : Colors.grey.shade300,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 14),

                            // Stop Name & Status
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 20),
                                padding: isStudentTarget
                                    ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
                                    : EdgeInsets.zero,
                                decoration: isStudentTarget
                                    ? BoxDecoration(
                                        color: Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.amber.shade300),
                                      )
                                    : null,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  stop['name'] ?? 'Stop',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14,
                                                    fontWeight: isCurrent || isStudentTarget ? FontWeight.w700 : FontWeight.w500,
                                                    color: isCurrent
                                                        ? const Color(0xFF1E3A8A)
                                                        : (isCrossed ? Colors.grey.shade700 : const Color(0xFF0F172A)),
                                                  ),
                                                ),
                                              ),
                                              if (isStudentTarget)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber.shade600,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    "MY STOP",
                                                    style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          if (isCurrent)
                                            Text(
                                              "Arrived at Stop (Crossed 70m geofence)",
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF2563EB),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      stop['time'] ?? (isCrossed ? "Passed" : (isCurrent ? "Now" : "Upcoming")),
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isCrossed
                                            ? Colors.green
                                            : (isCurrent ? const Color(0xFF2563EB) : Colors.grey.shade500),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
