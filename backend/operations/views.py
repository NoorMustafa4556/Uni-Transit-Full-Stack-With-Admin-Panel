from rest_framework import views, permissions, status
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from django.utils import timezone
from django.db import transaction
from .models import (
    ChangeRequest, EmergencySOS, SupportTicket,
    Notification, AuditLog, TransportContact, Faq, AppConfig
)
from .serializers import (
    ChangeRequestSerializer, EmergencySOSSerializer, SupportTicketSerializer,
    NotificationSerializer, AuditLogSerializer, TransportContactSerializer,
    FaqSerializer, AppConfigSerializer
)
from accounts.permissions import IsNotBlocked, IsAdminStaff, IsSuperAdmin
from transit.models import Hub, Stop, Route, RouteCategory
from transit.serializers import HubSerializer, StopSerializer, RouteSerializer, RouteCategorySerializer
from schedules.models import ScheduleProfile, TimeSlot, SlotBusAssignment
from schedules.serializers import ScheduleProfileSerializer, TimeSlotSerializer, SlotBusAssignmentSerializer

ENTITY_MODEL_SERIALIZER_MAP = {
    'hub': (Hub, HubSerializer),
    'stop': (Stop, StopSerializer),
    'route': (Route, RouteSerializer),
    'route_category': (RouteCategory, RouteCategorySerializer),
    'schedule_profile': (ScheduleProfile, ScheduleProfileSerializer),
    'time_slot': (TimeSlot, TimeSlotSerializer),
    'slot_assignment': (SlotBusAssignment, SlotBusAssignmentSerializer),
}

# --- Higher Authority Approval Queue ---

class ApprovalQueueListView(views.APIView):
    permission_classes = [IsAdminStaff]

    def get(self, request):
        status_param = request.query_params.get('status')
        queryset = ChangeRequest.objects.all().order_by('-created_at')
        if status_param:
            queryset = queryset.filter(status=status_param)
        serializer = ChangeRequestSerializer(queryset, many=True)
        return Response(serializer.data)


class ApprovalApproveView(views.APIView):
    permission_classes = [IsSuperAdmin]

    def post(self, request, pk):
        cr = get_object_or_404(ChangeRequest, pk=pk)
        if cr.status != 'pending':
            return Response({'detail': f'Cannot approve request with status {cr.status}.'}, status=status.HTTP_400_BAD_REQUEST)

        mapping = ENTITY_MODEL_SERIALIZER_MAP.get(cr.entity_type)
        if not mapping:
            return Response({'detail': f'Unknown entity type: {cr.entity_type}'}, status=status.HTTP_400_BAD_REQUEST)

        model_class, serializer_class = mapping
        payload = cr.payload_json or {}

        try:
            with transaction.atomic():
                if cr.action == 'create':
                    serializer = serializer_class(data=payload)
                    if not serializer.is_valid():
                        return Response({'detail': 'Invalid payload', 'errors': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)
                    instance = serializer.save()
                    target_repr = f"{cr.entity_type} #{instance.pk}: {str(instance)}"

                elif cr.action in ['update', 'patch']:
                    instance = get_object_or_404(model_class, pk=cr.entity_id)
                    serializer = serializer_class(instance, data=payload, partial=True)
                    if not serializer.is_valid():
                        return Response({'detail': 'Invalid payload', 'errors': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)
                    instance = serializer.save()
                    target_repr = f"{cr.entity_type} #{instance.pk}: {str(instance)}"

                elif cr.action == 'delete':
                    instance = get_object_or_404(model_class, pk=cr.entity_id)
                    target_repr = f"{cr.entity_type} #{cr.entity_id}: {str(instance)}"
                    instance.delete()

                cr.status = 'approved'
                cr.reviewed_by = request.user
                cr.reviewed_at = timezone.now()
                cr.review_note = request.data.get('review_note', 'Approved by Super Admin.')
                cr.save()

                AuditLog.objects.create(
                    actor=request.user,
                    action=f"approve_{cr.entity_type}_{cr.action}",
                    target=f"Approved CR #{cr.id} -> {target_repr}",
                    details=f"Approved by {request.user.name}. Review note: {cr.review_note}"
                )

            return Response({
                'message': f'ChangeRequest #{cr.id} approved and executed successfully.',
                'change_request': ChangeRequestSerializer(cr).data
            }, status=status.HTTP_200_OK)

        except Exception as e:
            return Response({'detail': f'Approval failed: {str(e)}'}, status=status.HTTP_400_BAD_REQUEST)


class ApprovalRejectView(views.APIView):
    permission_classes = [IsSuperAdmin]

    def post(self, request, pk):
        cr = get_object_or_404(ChangeRequest, pk=pk)
        if cr.status != 'pending':
            return Response({'detail': f'Cannot reject request with status {cr.status}.'}, status=status.HTTP_400_BAD_REQUEST)

        review_note = request.data.get('review_note', 'Rejected by Super Admin.')
        cr.status = 'rejected'
        cr.reviewed_by = request.user
        cr.reviewed_at = timezone.now()
        cr.review_note = review_note
        cr.save()

        AuditLog.objects.create(
            actor=request.user,
            action=f"reject_{cr.entity_type}",
            target=f"Rejected CR #{cr.id} ({cr.action} {cr.entity_type})",
            details=f"Reason: {review_note}"
        )

        return Response({
            'message': f'ChangeRequest #{cr.id} rejected.',
            'change_request': ChangeRequestSerializer(cr).data
        })


# --- Emergency SOS ---

class EmergencySOSListCreateView(views.APIView):
    permission_classes = [permissions.IsAuthenticated, IsNotBlocked]

    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAdminStaff()]
        return [permissions.IsAuthenticated(), IsNotBlocked()]

    def get(self, request):
        status_param = request.query_params.get('status')
        sos_list = EmergencySOS.objects.all().order_by('-created_at')
        if status_param:
            sos_list = sos_list.filter(status=status_param)
        return Response(EmergencySOSSerializer(sos_list, many=True).data)

    def post(self, request):
        lat = request.data.get('latitude')
        lng = request.data.get('longitude')
        message = request.data.get('message', '')
        trip_id = request.data.get('trip_id')

        if lat is None or lng is None:
            return Response({'detail': 'latitude and longitude are required.'}, status=status.HTTP_400_BAD_REQUEST)

        sos = EmergencySOS.objects.create(
            user=request.user,
            trip_id=trip_id,
            latitude=float(lat),
            longitude=float(lng),
            message=message or f"Emergency SOS triggered by {request.user.name}",
            status='open'
        )

        AuditLog.objects.create(
            actor=request.user,
            action="sos_triggered",
            target=f"EmergencySOS #{sos.id}",
            details=f"User {request.user.name} ({request.user.phone}) at ({lat}, {lng})"
        )

        # Broadcast live SOS alert to admin fleet WebSocket group
        from asgiref.sync import async_to_sync
        from channels.layers import get_channel_layer
        channel_layer = get_channel_layer()
        if channel_layer:
            async_to_sync(channel_layer.group_send)(
                "admin_fleet",
                {
                    "type": "sos_alert_broadcast",
                    "sos": {
                        "id": sos.id,
                        "user_name": request.user.name,
                        "user_phone": request.user.phone,
                        "latitude": sos.latitude,
                        "longitude": sos.longitude,
                        "message": sos.message,
                        "created_at": sos.created_at.isoformat(),
                    }
                }
            )

        return Response(EmergencySOSSerializer(sos).data, status=status.HTTP_201_CREATED)


class EmergencySOSResolveView(views.APIView):
    permission_classes = [IsAdminStaff]

    def patch(self, request, pk):
        sos = get_object_or_404(EmergencySOS, pk=pk)
        sos.status = 'resolved'
        sos.resolved_by = request.user
        sos.resolved_at = timezone.now()
        sos.save()

        AuditLog.objects.create(
            actor=request.user,
            action="sos_resolved",
            target=f"EmergencySOS #{sos.id}",
            details=f"Resolved by admin {request.user.name}"
        )
        return Response(EmergencySOSSerializer(sos).data)


class EmergencySOSReviewView(views.APIView):
    permission_classes = [permissions.IsAuthenticated, IsNotBlocked]

    def post(self, request, pk):
        sos = get_object_or_404(EmergencySOS, pk=pk, user=request.user)
        rating = request.data.get('review_rating')
        comment = request.data.get('review_comment', '')

        if rating is not None:
            sos.review_rating = int(rating)
        sos.review_comment = comment
        sos.save()
        return Response(EmergencySOSSerializer(sos).data)


# --- Support Tickets ---

class SupportTicketListCreateView(views.APIView):
    permission_classes = [permissions.IsAuthenticated, IsNotBlocked]

    def get(self, request):
        if request.user.role in ['sub_admin', 'super_admin']:
            tickets = SupportTicket.objects.all().order_by('-created_at')
        else:
            tickets = SupportTicket.objects.filter(user=request.user).order_by('-created_at')

        status_param = request.query_params.get('status')
        if status_param:
            tickets = tickets.filter(status=status_param)

        return Response(SupportTicketSerializer(tickets, many=True).data)

    def post(self, request):
        issue = request.data.get('issue')
        trip_id = request.data.get('trip_id')
        if not issue:
            return Response({'detail': 'issue text is required.'}, status=status.HTTP_400_BAD_REQUEST)

        ticket = SupportTicket.objects.create(
            user=request.user,
            trip_id=trip_id,
            issue=issue,
            status='open',
            user_read=True,
            admin_read=False,
        )
        return Response(SupportTicketSerializer(ticket).data, status=status.HTTP_201_CREATED)


class SupportTicketDetailView(views.APIView):
    permission_classes = [permissions.IsAuthenticated, IsNotBlocked]

    def get(self, request, pk):
        if request.user.role in ['sub_admin', 'super_admin']:
            ticket = get_object_or_404(SupportTicket, pk=pk)
            ticket.admin_read = True
            ticket.save(update_fields=['admin_read'])
        else:
            ticket = get_object_or_404(SupportTicket, pk=pk, user=request.user)
            ticket.user_read = True
            ticket.save(update_fields=['user_read'])

        return Response(SupportTicketSerializer(ticket).data)

    def patch(self, request, pk):
        ticket = get_object_or_404(SupportTicket, pk=pk)
        is_admin = request.user.role in ['sub_admin', 'super_admin']

        if is_admin:
            if 'admin_reply' in request.data:
                ticket.admin_reply = request.data['admin_reply']
                ticket.user_read = False
            if 'status' in request.data:
                ticket.status = request.data['status']
            ticket.save()
            return Response(SupportTicketSerializer(ticket).data)

        elif ticket.user == request.user:
            if 'issue' in request.data:
                ticket.issue = request.data['issue']
                ticket.admin_read = False
                ticket.save()
            return Response(SupportTicketSerializer(ticket).data)

        return Response({'detail': 'Permission denied.'}, status=status.HTTP_403_FORBIDDEN)


# --- Notifications, Contacts, FAQs, AppConfig, AuditLogs ---

class NotificationListCreateView(views.APIView):
    permission_classes = [permissions.IsAuthenticated, IsNotBlocked]

    def get(self, request):
        user = request.user
        qs = Notification.objects.filter(
            target_role__in=['all', user.role]
        ) | Notification.objects.filter(target_user=user)
        return Response(NotificationSerializer(qs.order_by('-created_at')[:50], many=True).data)

    def post(self, request):
        if not (request.user.role in ['sub_admin', 'super_admin']):
            return Response({'detail': 'Admin access required.'}, status=status.HTTP_403_FORBIDDEN)
        serializer = NotificationSerializer(data=request.data)
        if serializer.is_valid():
            notif = serializer.save()
            return Response(NotificationSerializer(notif).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class NotificationMarkReadView(views.APIView):
    permission_classes = [permissions.IsAuthenticated, IsNotBlocked]

    def patch(self, request, pk):
        notif = get_object_or_404(Notification, pk=pk)
        notif.is_read = True
        notif.save(update_fields=['is_read'])
        return Response({'message': 'Marked as read.'})


class AuditLogListView(views.APIView):
    permission_classes = [IsAdminStaff]

    def get(self, request):
        logs = AuditLog.objects.select_related('actor').all()[:100]
        return Response(AuditLogSerializer(logs, many=True).data)


class TransportContactListCreateView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [permissions.AllowAny()]
        return [IsAdminStaff()]

    def get(self, request):
        contacts = TransportContact.objects.filter(is_active=True)
        return Response(TransportContactSerializer(contacts, many=True).data)

    def post(self, request):
        serializer = TransportContactSerializer(data=request.data)
        if serializer.is_valid():
            contact = serializer.save()
            return Response(TransportContactSerializer(contact).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class FaqListView(views.APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        faqs = Faq.objects.filter(is_active=True).order_by('order', 'id')
        category = request.query_params.get('category')
        if category:
            faqs = faqs.filter(category__icontains=category)
        return Response(FaqSerializer(faqs, many=True).data)


class AppConfigView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [permissions.AllowAny()]
        return [IsSuperAdmin()]

    def get(self, request):
        config = AppConfig.get_config()
        return Response(AppConfigSerializer(config).data)

    def patch(self, request):
        config = AppConfig.get_config()
        serializer = AppConfigSerializer(config, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
