from django.urls import path
from .views import (
    ApprovalQueueListView, ApprovalApproveView, ApprovalRejectView,
    EmergencySOSListCreateView, EmergencySOSResolveView, EmergencySOSReviewView,
    SupportTicketListCreateView, SupportTicketDetailView,
    NotificationListCreateView, NotificationMarkReadView,
    AuditLogListView, TransportContactListCreateView, TransportContactDetailView,
    FaqListView, FaqDetailView, AppConfigView
)

urlpatterns = [
    # Higher Authority Approval Queue
    path('operations/approvals/', ApprovalQueueListView.as_view(), name='operations-approvals'),
    path('operations/approvals/<int:pk>/approve/', ApprovalApproveView.as_view(), name='operations-approval-approve'),
    path('operations/approvals/<int:pk>/reject/', ApprovalRejectView.as_view(), name='operations-approval-reject'),

    # Emergency SOS
    path('operations/sos/', EmergencySOSListCreateView.as_view(), name='operations-sos'),
    path('operations/sos/<int:pk>/resolve/', EmergencySOSResolveView.as_view(), name='operations-sos-resolve'),
    path('operations/sos/<int:pk>/review/', EmergencySOSReviewView.as_view(), name='operations-sos-review'),

    # Support Tickets
    path('operations/tickets/', SupportTicketListCreateView.as_view(), name='operations-tickets'),
    path('operations/tickets/<int:pk>/', SupportTicketDetailView.as_view(), name='operations-ticket-detail'),

    # Notifications, Contacts, FAQs, Config, AuditLogs
    path('operations/notifications/', NotificationListCreateView.as_view(), name='operations-notifications'),
    path('operations/notifications/<int:pk>/read/', NotificationMarkReadView.as_view(), name='operations-notification-read'),
    path('operations/audit-logs/', AuditLogListView.as_view(), name='operations-audit-logs'),
    path('operations/contacts/', TransportContactListCreateView.as_view(), name='operations-contacts'),
    path('operations/contacts/<int:pk>/', TransportContactDetailView.as_view(), name='operations-contact-detail'),
    path('operations/faqs/', FaqListView.as_view(), name='operations-faqs'),
    path('operations/faqs/<int:pk>/', FaqDetailView.as_view(), name='operations-faq-detail'),
    path('operations/config/', AppConfigView.as_view(), name='operations-config'),
]
