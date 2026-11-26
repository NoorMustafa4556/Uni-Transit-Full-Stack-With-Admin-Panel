from django.urls import path
from .views import (
    ScheduleProfileListCreateView, ScheduleProfileDetailView,
    ActiveSlotsView, TimeSlotListCreateView, TimeSlotDetailView,
    SlotBusAssignmentListCreateView, SlotBusAssignmentDetailView
)

urlpatterns = [
    path('schedules/profiles/', ScheduleProfileListCreateView.as_view(), name='schedule-profiles'),
    path('schedules/profiles/<int:pk>/', ScheduleProfileDetailView.as_view(), name='schedule-profile-detail'),
    path('schedules/active-slots/', ActiveSlotsView.as_view(), name='schedule-active-slots'),
    path('schedules/time-slots/', TimeSlotListCreateView.as_view(), name='schedule-time-slots'),
    path('schedules/time-slots/<int:pk>/', TimeSlotDetailView.as_view(), name='schedule-time-slot-detail'),
    path('schedules/slot-assignments/', SlotBusAssignmentListCreateView.as_view(), name='schedule-slot-assignments'),
    path('schedules/slot-assignments/<int:pk>/', SlotBusAssignmentDetailView.as_view(), name='schedule-slot-assignment-detail'),
]
