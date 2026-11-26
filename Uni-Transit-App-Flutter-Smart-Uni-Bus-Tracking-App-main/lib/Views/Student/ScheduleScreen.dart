import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uni_transit/Models/BusSchedule.dart';
import 'package:uni_transit/Services/ScheduleService.dart';
import 'package:uni_transit/Core/Constants/AppColors.dart';
import 'package:uni_transit/ViewModels/BusProvider.dart';
import 'package:uni_transit/Widgets/LiveBusTimelineSheet.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  final _scheduleService = ScheduleService();
  
  late DateTime _selectedDate;
  late DateTime _currentMonth;
  late ScrollController _calendarScrollController;
  String _selectedTypeFilter = 'All';
  String _selectedSession = 'All'; // Morning, Afternoon, Evening
  String _activeProfileTitle = "Spring 2026 Regular Schedule";
  List<Map<String, dynamic>> _activeSlots = [];
  bool _isLoadingSlots = false;

  final List<String> _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month);
    _calendarScrollController = ScrollController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate();
      _loadProfileAndSlots();
    });
  }

  Future<void> _loadProfileAndSlots() async {
    setState(() => _isLoadingSlots = true);
    try {
      final profiles = await _scheduleService.getScheduleProfiles();
      if (profiles.isNotEmpty) {
        final active = profiles.firstWhere((p) => p['is_active'] == true, orElse: () => profiles.first);
        _activeProfileTitle = active['title'] ?? _activeProfileTitle;
      }
      final slots = await _scheduleService.getActiveSlots();
      if (mounted) {
        setState(() {
          _activeSlots = slots;
          _isLoadingSlots = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSlots = false);
    }
  }

  void _scrollToSelectedDate() {
    if (_calendarScrollController.hasClients) {
      final index = _selectedDate.day - 1;
      _calendarScrollController.animateTo(
        index * 62.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  String _getWeekdayName(DateTime date) {
    return _weekdays[date.weekday - 1];
  }

  String _getShift(String timeStr) {
    try {
      final cleanTime = timeStr.trim().toLowerCase();
      if (cleanTime.contains('am')) {
        final hour = int.parse(cleanTime.split(':')[0]);
        if (hour < 12) return 'Morning';
      } else if (cleanTime.contains('pm')) {
        final hour = int.parse(cleanTime.split(':')[0]);
        if (hour == 12 || hour < 4) return 'Afternoon';
        return 'Evening';
      }
    } catch (_) {}
    return 'Morning';
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final List<String> monthNames = [
      'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'
    ];
    final liveBuses = ref.watch(busProvider).liveBusData;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Bus Schedule",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primaryNavy,
        elevation: 2,
        shadowColor: Colors.black26,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Active Profile Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, color: Colors.amber, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "ACTIVE PROFILE: $_activeProfileTitle",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // 1. Calendar Header (Month Switcher)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, color: AppColors.primaryNavy),
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                    });
                  },
                ),
                Text(
                  "${monthNames[_currentMonth.month - 1]} ${_currentMonth.year}",
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                    letterSpacing: 1.0,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, color: AppColors.primaryNavy),
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                    });
                  },
                ),
              ],
            ),
          ),

          // 2. Horizontal Date Strip
          Container(
            height: 76,
            color: Colors.white,
            child: ListView.builder(
              controller: _calendarScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: daysInMonth,
              itemBuilder: (context, index) {
                final day = index + 1;
                final date = DateTime(_currentMonth.year, _currentMonth.month, day);
                final isSelected = date.year == _selectedDate.year &&
                    date.month == _selectedDate.month &&
                    date.day == _selectedDate.day;
                final weekday = _getWeekdayName(date).substring(0, 3).toUpperCase();

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                    });
                  },
                  child: Container(
                    width: 54,
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryNavy : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryNavy : Colors.grey.shade200,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primaryNavy.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          weekday,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white70 : Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "$day",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 3. Filter Chips (Shift & Gender)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                // Session Filter Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSession,
                      icon: const Icon(Icons.arrow_drop_down_rounded),
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Shifts')),
                        DropdownMenuItem(value: 'Morning', child: Text('Morning')),
                        DropdownMenuItem(value: 'Afternoon', child: Text('Afternoon')),
                        DropdownMenuItem(value: 'Evening', child: Text('Evening')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSession = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Gender Filter Chips
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Boys', 'Girls', 'Combined'].map((filter) {
                        final isSelected = _selectedTypeFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: isSelected,
                            selectedColor: AppColors.primaryNavy,
                            labelStyle: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : Colors.grey.shade700,
                            ),
                            onSelected: (selected) {
                              setState(() {
                                _selectedTypeFilter = filter;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Schedules list
          Expanded(
            child: StreamBuilder<List<BusSchedule>>(
              stream: _scheduleService.getSchedules(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _isLoadingSlots) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy));
                }
                final allSchedules = snapshot.data ?? [];
                if (allSchedules.isEmpty && _activeSlots.isEmpty) {
                  return _buildEmptyState();
                }

                final selectedDateStr = _formatDate(_selectedDate);
                final selectedDayName = _getWeekdayName(_selectedDate);

                final filteredSchedules = allSchedules.where((schedule) {
                  if (_selectedTypeFilter != 'All') {
                    final typeLower = schedule.type.toLowerCase();
                    final filterLower = _selectedTypeFilter.toLowerCase();
                    if (!typeLower.contains(filterLower) && !filterLower.contains(typeLower)) {
                      return false;
                    }
                  }
                  return true;
                }).toList();

                final Map<String, List<BusSchedule>> shiftGroups = {
                  'Morning': [],
                  'Afternoon': [],
                  'Evening': [],
                };

                for (var schedule in filteredSchedules) {
                  final shift = _getShift(schedule.departureTime);
                  shiftGroups[shift]?.add(schedule);
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: [
                    if ((_selectedSession == 'All' || _selectedSession == 'Morning') && (shiftGroups['Morning']?.isNotEmpty ?? false))
                      _buildMobileShiftTable(context, 'MORNING SESSION', shiftGroups['Morning']!, liveBuses, selectedDateStr),
                    if ((_selectedSession == 'All' || _selectedSession == 'Afternoon') && (shiftGroups['Afternoon']?.isNotEmpty ?? false))
                      _buildMobileShiftTable(context, 'AFTERNOON SESSION', shiftGroups['Afternoon']!, liveBuses, selectedDateStr),
                    if ((_selectedSession == 'All' || _selectedSession == 'Evening') && (shiftGroups['Evening']?.isNotEmpty ?? false))
                      _buildMobileShiftTable(context, 'EVENING SESSION', shiftGroups['Evening']!, liveBuses, selectedDateStr),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileShiftTable(
    BuildContext context,
    String title,
    List<BusSchedule> schedules,
    Map<String, dynamic> liveBuses,
    String selectedDateStr,
  ) {
    schedules.sort((a, b) => a.departureTime.compareTo(b.departureTime));

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryNavy.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  title.contains('MORNING')
                      ? Icons.light_mode_rounded
                      : (title.contains('AFTERNOON') ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded),
                  color: AppColors.primaryNavy,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.primaryNavy,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('TIME', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey[400])),
                ),
                Expanded(
                  flex: 5,
                  child: Text('ROUTE', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey[400])),
                ),
                Expanded(
                  flex: 4,
                  child: Text('SLOT COUNTER', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey[400])),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text('TRACK', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey[400])),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: schedules.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.borderLight),
            itemBuilder: (context, index) {
              final schedule = schedules[index];

              // Find matching active slot
              final matchingSlot = _activeSlots.firstWhere(
                (s) => s['id'].toString() == schedule.id,
                orElse: () => <String, dynamic>{},
              );

              final totalBuses = matchingSlot['total_buses'] ?? 1;
              final dispatched = matchingSlot['dispatched_count'] ?? 1;
              final remaining = matchingSlot['remaining_count'] ?? 0;
              final isLastBus = matchingSlot['is_last_bus'] ?? false;

              // Check if bus is live
              final isLive = liveBuses.containsKey(schedule.busNumber);

              Color typeColor = AppColors.primaryNavy;
              final typeLower = schedule.type.toLowerCase();
              if (typeLower.contains('girls')) {
                typeColor = AppColors.girlsSpecial;
              } else if (typeLower.contains('boys')) {
                typeColor = AppColors.boysSpecial;
              }

              return InkWell(
                onTap: () {
                  LiveBusTimelineSheet.show(
                    context,
                    busNumber: schedule.busNumber,
                    gender: schedule.type,
                    totalBuses: totalBuses,
                    dispatchedCount: dispatched,
                    remainingCount: remaining,
                    isLastBus: isLastBus,
                    etaText: isLive ? "Live on Route" : "Scheduled",
                    distanceText: isLive ? "Active" : "---",
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      // Departure Time
                      Expanded(
                        flex: 3,
                        child: Text(
                          schedule.departureTime,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      // Route & Gender
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              schedule.route,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E293B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              schedule.type,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: typeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Slot Dispatch Counter + Last Bus Alert
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Disp: $dispatched/$totalBuses",
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF334155),
                              ),
                            ),
                            if (isLastBus)
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.red.shade300),
                                ),
                                child: Text(
                                  "LAST BUS",
                                  style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.red),
                                ),
                              )
                            else
                              Text(
                                "$remaining left",
                                style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade500),
                              ),
                          ],
                        ),
                      ),
                      // Live Action Button
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isLive ? Colors.green.shade50 : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isLive ? Icons.sensors_rounded : Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: isLive ? Colors.green : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
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
          Icon(Icons.directions_bus_filled_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            "No schedules found for this selection",
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
