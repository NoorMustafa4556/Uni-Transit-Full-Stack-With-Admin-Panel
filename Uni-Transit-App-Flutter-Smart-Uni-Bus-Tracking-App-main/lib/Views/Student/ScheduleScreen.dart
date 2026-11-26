import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uni_transit/Models/BusSchedule.dart';
import 'package:uni_transit/Services/ScheduleService.dart';
import 'package:uni_transit/Core/Constants/AppColors.dart';
import 'package:uni_transit/Views/Student/MapScreen.dart';
import 'package:uni_transit/ViewModels/BusProvider.dart';
import 'package:uni_transit/Views/Student/StudentDashboard.dart';
import 'package:uni_transit/ViewModels/RouteProvider.dart';

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
  String _selectedSession = 'All'; // For Morning/Afternoon/Evening dropdown
  final List<String> _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month);
    _calendarScrollController = ScrollController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDate());
  }

  void _scrollToSelectedDate() {
    if (_calendarScrollController.hasClients) {
      final index = _selectedDate.day - 1;
      _calendarScrollController.animateTo(
        index * 62.0, // Width of date cell (54) + margin (8)
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
    // Expected format: "08:00 AM"
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final List<String> monthNames = [
      'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'
    ];

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
        centerTitle: false,
      ),
      body: Column(
        children: [
          // 1. Calendar Header
          Container(
            color: Theme.of(context).cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${monthNames[_currentMonth.month - 1]} ${_currentMonth.year}",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? AppColors.primaryYellow : AppColors.primaryNavy,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left_rounded, color: isDark ? AppColors.primaryYellow : AppColors.primaryNavy),
                      onPressed: () {
                        setState(() {
                          _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                        });
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right_rounded, color: isDark ? AppColors.primaryYellow : AppColors.primaryNavy),
                      onPressed: () {
                        setState(() {
                          _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Horizontal Calendar list
          Container(
            height: 75,
            color: Theme.of(context).cardColor,
            padding: const EdgeInsets.only(bottom: 12),
            child: ListView.builder(
              controller: _calendarScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: daysInMonth,
              itemBuilder: (context, index) {
                final date = DateTime(_currentMonth.year, _currentMonth.month, index + 1);
                final today = DateTime.now();
                final isPast = DateTime(date.year, date.month, date.day).isBefore(DateTime(today.year, today.month, today.day));
                final isSelected = date.year == _selectedDate.year &&
                    date.month == _selectedDate.month &&
                    date.day == _selectedDate.day;

                final weekday = _getWeekdayName(date).substring(0, 3).toUpperCase();

                return GestureDetector(
                  onTap: isPast ? null : () {
                    setState(() {
                      _selectedDate = date;
                    });
                  },
                  child: Container(
                    width: 54,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? (isDark ? AppColors.primaryYellow : AppColors.primaryNavy) 
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                            ? Colors.transparent 
                            : (isDark ? Colors.white10 : Colors.grey[200]!),
                      ),
                    ),
                    child: Opacity(
                      opacity: isPast ? 0.35 : 1.0,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            weekday,
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: isSelected 
                                  ? (isDark ? Colors.black87 : Colors.white70) 
                                  : Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${index + 1}",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isSelected 
                                  ? (isDark ? Colors.black : Colors.white) 
                                  : (isDark ? Colors.white : AppColors.textDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 3. Dropdowns and filters
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedSession,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: GoogleFonts.poppins(color: isDark ? Colors.white : AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Sessions')),
                      DropdownMenuItem(value: 'Morning', child: Text('Morning')),
                      DropdownMenuItem(value: 'Afternoon', child: Text('Afternoon')),
                      DropdownMenuItem(value: 'Evening', child: Text('Evening')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedSession = val!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 45,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: ['All', 'Girls', 'Boys', 'Combined'].map((filter) {
                        final isSelected = _selectedTypeFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              filter,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: isSelected ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.primaryNavy,
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
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
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('active_buses')
                  .stream(primaryKey: ['bus_number']),
              builder: (context, activeBusesSnapshot) {
                final activeBuses = activeBusesSnapshot.data ?? [];

                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: Supabase.instance.client
                      .from('completed_trips')
                      .stream(primaryKey: ['id']),
                  builder: (context, completedTripsSnapshot) {
                    final completedTrips = completedTripsSnapshot.data ?? [];

                    return StreamBuilder<List<BusSchedule>>(
                      stream: _scheduleService.getSchedules(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy));
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return _buildEmptyState();
                        }

                        final allSchedules = snapshot.data!;
                        final selectedDateStr = _formatDate(_selectedDate);
                        final selectedDayName = _getWeekdayName(_selectedDate);

                        final filteredSchedules = allSchedules.where((schedule) {
                          if (schedule.busNumber == 'TBA' || schedule.departureTime == 'TBA') {
                            return false;
                          }

                          if (_selectedTypeFilter != 'All') {
                            final typeLower = schedule.type.toLowerCase();
                            final filterLower = _selectedTypeFilter.toLowerCase();
                            if (!typeLower.contains(filterLower) && !filterLower.contains(typeLower)) {
                              return false;
                            }
                          }

                          if (schedule.date != null && schedule.date!.isNotEmpty) {
                            return schedule.date == selectedDateStr;
                          }
                          if (schedule.operatingDays != null && schedule.operatingDays!.isNotEmpty) {
                            return schedule.operatingDays!.contains(selectedDayName);
                          }
                          return selectedDayName != 'Saturday' && selectedDayName != 'Sunday';
                        }).toList();

                        if (filteredSchedules.isEmpty) {
                          return _buildEmptyState();
                        }

                        final Map<String, List<BusSchedule>> shiftGroups = {
                          'Morning': [],
                          'Afternoon': [],
                          'Evening': [],
                        };

                        for (var schedule in filteredSchedules) {
                          final shift = _getShift(schedule.departureTime);
                          shiftGroups[shift]!.add(schedule);
                        }

                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                          children: [
                            if ((_selectedSession == 'All' || _selectedSession == 'Morning') && shiftGroups['Morning']!.isNotEmpty)
                              _buildMobileShiftTable(context, 'MORNING SESSION', shiftGroups['Morning']!, activeBuses, completedTrips, selectedDateStr),
                            if ((_selectedSession == 'All' || _selectedSession == 'Afternoon') && shiftGroups['Afternoon']!.isNotEmpty)
                              _buildMobileShiftTable(context, 'AFTERNOON SESSION', shiftGroups['Afternoon']!, activeBuses, completedTrips, selectedDateStr),
                            if ((_selectedSession == 'All' || _selectedSession == 'Evening') && shiftGroups['Evening']!.isNotEmpty)
                              _buildMobileShiftTable(context, 'EVENING SESSION', shiftGroups['Evening']!, activeBuses, completedTrips, selectedDateStr),
                          ],
                        );
                      },
                    );
                  },
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
    List<Map<String, dynamic>> activeBuses,
    List<Map<String, dynamic>> completedTrips,
    String selectedDateStr,
  ) {
    schedules.sort((a, b) => a.departureTime.compareTo(b.departureTime));

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[150] ?? const Color(0xFFF3F4F6)),
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
                    fontSize: 11,
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
                  child: Text('TIME', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey[400])),
                ),
                Expanded(
                  flex: 5,
                  child: Text('ROUTE', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey[400])),
                ),
                Expanded(
                  flex: 4,
                  child: Text('BUS IDS', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey[400])),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text('LIVE', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey[400])),
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

              String scheduleStatus = 'UPCOMING';
              
              final isActive = activeBuses.any((b) => 
                  b['schedule_id'] == schedule.id || b['bus_number'] == schedule.busNumber);
              
              final isCompleted = completedTrips.any((t) => 
                  (t['schedule_id'] == schedule.id || t['bus_number'] == schedule.busNumber) && 
                  t['date'] == selectedDateStr && 
                  t['status'] == 'completed');

              if (isActive) {
                scheduleStatus = 'ACTIVE';
              } else if (isCompleted) {
                scheduleStatus = 'COMPLETED';
              }

              String? liveBusId;
              List<String> scheduledBuses = schedule.busNumber
                  .split(RegExp(r'[-, ]+'))
                  .where((s) => s.isNotEmpty)
                  .toList();

              for (var bus in scheduledBuses) {
                if (activeBuses.any((b) => b['bus_number'] == bus)) {
                  liveBusId = bus;
                  break;
                }
              }
              final isLive = liveBusId != null || scheduleStatus == 'ACTIVE';

              Color typeColor = AppColors.primaryNavy;
              final typeLower = schedule.type.toLowerCase();
              if (typeLower.contains('girls')) {
                typeColor = AppColors.girlsSpecial;
              } else if (typeLower.contains('boys')) {
                typeColor = AppColors.boysSpecial;
              }

              return InkWell(
                onTap: isLive ? () {
                  ref.read(routeProvider.notifier).selectRoute(schedule.route);
                  ref.read(studentNavIndexProvider.notifier).setIndex(0);
                } : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          schedule.departureTime,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              schedule.route,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              schedule.type,
                              style: GoogleFonts.poppins(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: typeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            schedule.busNumber,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryNavy,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: isLive
                              ? Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent[700]!.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.gps_fixed_rounded,
                                    size: 14,
                                    color: Colors.greenAccent[700],
                                  ),
                                )
                              : (scheduleStatus == 'COMPLETED'
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.green.withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Text(
                                        "Done",
                                        style: GoogleFonts.poppins(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.gps_off_rounded,
                                      size: 14,
                                      color: Colors.grey[300],
                                    )),
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
          Icon(Icons.calendar_month_outlined, size: 50, color: Colors.grey[200]),
          const SizedBox(height: 12),
          Text("No active schedules", style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13)),
        ],
      ),
    );
  }
}
