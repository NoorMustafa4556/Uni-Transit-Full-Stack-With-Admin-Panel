import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uni_transit/Models/BusSchedule.dart';
import 'package:uni_transit/Services/ScheduleService.dart';

final scheduleServiceProvider = Provider<ScheduleService>((ref) => ScheduleService());

/// Stream provider that listens to schedules in real-time from Django REST backend.
final schedulesStreamProvider = StreamProvider<List<BusSchedule>>((ref) {
  return ref.watch(scheduleServiceProvider).getSchedules();
});

/// Future provider for raw active slots with live slot counters (total_buses, dispatched_count, remaining_count, is_last_bus)
final activeSlotsProvider = FutureProvider.family<List<Map<String, dynamic>>, Map<String, dynamic>?>((ref, filters) async {
  final service = ref.watch(scheduleServiceProvider);
  return service.getActiveSlots(
    routeId: filters?['route_id'],
    shift: filters?['shift'],
    dayType: filters?['day_type'],
    gender: filters?['gender'],
    tag: filters?['tag'],
  );
});

/// Represents the selected date and month state for the assigned routes calendar view.
class CalendarState {
  final DateTime selectedDate;
  final DateTime currentMonth;

  CalendarState({
    required this.selectedDate,
    required this.currentMonth,
  });

  CalendarState copyWith({
    DateTime? selectedDate,
    DateTime? currentMonth,
  }) {
    return CalendarState(
      selectedDate: selectedDate ?? this.selectedDate,
      currentMonth: currentMonth ?? this.currentMonth,
    );
  }
}

/// StateNotifier to manage the Assigned Routes Screen calendar selection.
class CalendarNotifier extends StateNotifier<CalendarState> {
  CalendarNotifier() : super(CalendarState(
    selectedDate: DateTime.now(),
    currentMonth: DateTime(DateTime.now().year, DateTime.now().month),
  ));

  void selectDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
  }

  void changeMonth(int offset) {
    final nextMonth = DateTime(state.currentMonth.year, state.currentMonth.month + offset);
    DateTime nextSelected;
    final now = DateTime.now();
    
    if (nextMonth.year == now.year && nextMonth.month == now.month) {
      nextSelected = now;
    } else {
      nextSelected = DateTime(nextMonth.year, nextMonth.month, 1);
    }
    
    state = CalendarState(
      selectedDate: nextSelected,
      currentMonth: nextMonth,
    );
  }
}

final calendarProvider = StateNotifierProvider.autoDispose<CalendarNotifier, CalendarState>((ref) {
  return CalendarNotifier();
});
