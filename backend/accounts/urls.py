from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    RegisterView, LoginView, MeView, FcmTokenView, ChangePasswordView,
    AdminStudentListView, AdminStudentStatusView,
    AdminDriverListCreateView, AdminDriverStatusView, AdminManagementView
)

urlpatterns = [
    # Auth endpoints
    path('auth/register/', RegisterView.as_view(), name='auth-register'),
    path('auth/login/', LoginView.as_view(), name='auth-login'),
    path('auth/token/refresh/', TokenRefreshView.as_view(), name='token-refresh'),
    path('auth/me/', MeView.as_view(), name='auth-me'),
    path('auth/fcm-token/', FcmTokenView.as_view(), name='auth-fcm-token'),
    path('auth/change-password/', ChangePasswordView.as_view(), name='auth-change-password'),

    # Admin endpoints
    path('admin/students/', AdminStudentListView.as_view(), name='admin-students-list'),
    path('admin/students/<int:pk>/status/', AdminStudentStatusView.as_view(), name='admin-student-status'),
    path('admin/drivers/', AdminDriverListCreateView.as_view(), name='admin-drivers-list-create'),
    path('admin/drivers/<int:pk>/status/', AdminDriverStatusView.as_view(), name='admin-driver-status'),
    path('admin/admins/', AdminManagementView.as_view(), name='admin-admins-list-create'),
]
