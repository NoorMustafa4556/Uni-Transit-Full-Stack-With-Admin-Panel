from django.urls import path
from .views import (
    DriverTripStartView, DriverTripStopView, DriverTripCrowdStatusView,
    DriverTripAlertCreateView, DriverLocationUpdateView,
    DriverActiveTripView, DriverTripHistoryView,
    StudentStopFeedView,
    AdminActiveTripsView, AdminTripHistoryView,
    AdminStopSkipAlertsView, AdminAnalyticsSummaryView
)

urlpatterns = [
    # Driver endpoints
    path('tracking/driver/trips/start/', DriverTripStartView.as_view(), name='driver-trip-start'),
    path('tracking/driver/trips/<int:pk>/stop/', DriverTripStopView.as_view(), name='driver-trip-stop'),
    path('tracking/driver/trips/<int:pk>/crowd-status/', DriverTripCrowdStatusView.as_view(), name='driver-trip-crowd-status'),
    path('tracking/driver/trips/<int:pk>/alert/', DriverTripAlertCreateView.as_view(), name='driver-trip-alert'),
    path('tracking/driver/trips/<int:pk>/location/', DriverLocationUpdateView.as_view(), name='driver-trip-location'),
    path('tracking/driver/trips/active/', DriverActiveTripView.as_view(), name='driver-trip-active'),
    path('tracking/driver/trips/history/', DriverTripHistoryView.as_view(), name='driver-trip-history'),

    # Student Live Bus Stop Feed (Track My Point)
    path('tracking/student/stop-feed/', StudentStopFeedView.as_view(), name='student-stop-feed'),

    # Admin monitoring
    path('tracking/admin/trips/active/', AdminActiveTripsView.as_view(), name='admin-trips-active'),
    path('tracking/admin/trips/history/', AdminTripHistoryView.as_view(), name='admin-trips-history'),
    path('tracking/admin/stop-skip-alerts/', AdminStopSkipAlertsView.as_view(), name='admin-stop-skip-alerts'),
    path('tracking/admin/analytics/summary/', AdminAnalyticsSummaryView.as_view(), name='admin-analytics-summary'),
]
