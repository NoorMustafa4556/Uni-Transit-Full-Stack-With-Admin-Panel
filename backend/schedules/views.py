from rest_framework import views, permissions, status
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from .models import ScheduleProfile, TimeSlot, SlotBusAssignment
from .serializers import ScheduleProfileSerializer, TimeSlotSerializer, SlotBusAssignmentSerializer
from accounts.permissions import IsAdminStaff
from operations.maker_checker import handle_maker_checker_mutation

class ScheduleProfileListCreateView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [permissions.AllowAny()]
        return [IsAdminStaff()]

    def get(self, request):
        profiles = ScheduleProfile.objects.all().order_by('-effective_from')
        return Response(ScheduleProfileSerializer(profiles, many=True).data)

    def post(self, request):
        return handle_maker_checker_mutation(request, 'schedule_profile', 'create', serializer_class=ScheduleProfileSerializer)


class ScheduleProfileDetailView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [permissions.AllowAny()]
        return [IsAdminStaff()]

    def get(self, request, pk):
        profile = get_object_or_404(ScheduleProfile, pk=pk)
        return Response(ScheduleProfileSerializer(profile).data)

    def put(self, request, pk):
        profile = get_object_or_404(ScheduleProfile, pk=pk)
        return handle_maker_checker_mutation(request, 'schedule_profile', 'update', entity_id=pk, serializer_class=ScheduleProfileSerializer, instance=profile)

    def patch(self, request, pk):
        profile = get_object_or_404(ScheduleProfile, pk=pk)
        return handle_maker_checker_mutation(request, 'schedule_profile', 'patch', entity_id=pk, serializer_class=ScheduleProfileSerializer, instance=profile)

    def delete(self, request, pk):
        profile = get_object_or_404(ScheduleProfile, pk=pk)
        return handle_maker_checker_mutation(request, 'schedule_profile', 'delete', entity_id=pk, instance=profile)


class ActiveSlotsView(views.APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        # Fetch active profile
        active_profile = ScheduleProfile.objects.filter(is_active=True).first()
        if not active_profile:
            return Response({'detail': 'No active schedule profile found.'}, status=status.HTTP_404_NOT_FOUND)

        slots = TimeSlot.objects.filter(profile=active_profile, is_active=True).select_related(
            'route', 'route__origin_hub', 'route__destination_hub'
        ).prefetch_related(
            'bus_assignments__bus',
            'bus_assignments__gender',
            'bus_assignments__tags',
            'bus_assignments__driver__user'
        )

        # Filters
        route_id = request.query_params.get('route_id')
        if route_id:
            slots = slots.filter(route_id=route_id)

        shift = request.query_params.get('shift')
        if shift:
            slots = slots.filter(shift=shift)

        day_type = request.query_params.get('day_type')
        if day_type:
            slots = slots.filter(day_type=day_type)

        gender = request.query_params.get('gender')
        if gender:
            slots = slots.filter(bus_assignments__gender__name__iexact=gender).distinct()

        tag = request.query_params.get('tag')
        if tag:
            slots = slots.filter(bus_assignments__tags__code__iexact=tag).distinct()

        serializer = TimeSlotSerializer(slots, many=True)
        return Response({
            'profile': ScheduleProfileSerializer(active_profile).data,
            'slots': serializer.data
        })


class TimeSlotListCreateView(views.APIView):
    permission_classes = [IsAdminStaff]

    def post(self, request):
        return handle_maker_checker_mutation(request, 'time_slot', 'create', serializer_class=TimeSlotSerializer)


class TimeSlotDetailView(views.APIView):
    permission_classes = [IsAdminStaff]

    def get(self, request, pk):
        slot = get_object_or_404(TimeSlot, pk=pk)
        return Response(TimeSlotSerializer(slot).data)

    def put(self, request, pk):
        slot = get_object_or_404(TimeSlot, pk=pk)
        return handle_maker_checker_mutation(request, 'time_slot', 'update', entity_id=pk, serializer_class=TimeSlotSerializer, instance=slot)

    def patch(self, request, pk):
        slot = get_object_or_404(TimeSlot, pk=pk)
        return handle_maker_checker_mutation(request, 'time_slot', 'patch', entity_id=pk, serializer_class=TimeSlotSerializer, instance=slot)

    def delete(self, request, pk):
        slot = get_object_or_404(TimeSlot, pk=pk)
        return handle_maker_checker_mutation(request, 'time_slot', 'delete', entity_id=pk, instance=slot)


class SlotBusAssignmentListCreateView(views.APIView):
    permission_classes = [IsAdminStaff]

    def post(self, request):
        return handle_maker_checker_mutation(request, 'slot_assignment', 'create', serializer_class=SlotBusAssignmentSerializer)


class SlotBusAssignmentDetailView(views.APIView):
    permission_classes = [IsAdminStaff]

    def get(self, request, pk):
        sba = get_object_or_404(SlotBusAssignment, pk=pk)
        return Response(SlotBusAssignmentSerializer(sba).data)

    def put(self, request, pk):
        sba = get_object_or_404(SlotBusAssignment, pk=pk)
        return handle_maker_checker_mutation(request, 'slot_assignment', 'update', entity_id=pk, serializer_class=SlotBusAssignmentSerializer, instance=sba)

    def patch(self, request, pk):
        sba = get_object_or_404(SlotBusAssignment, pk=pk)
        return handle_maker_checker_mutation(request, 'slot_assignment', 'patch', entity_id=pk, serializer_class=SlotBusAssignmentSerializer, instance=sba)

    def delete(self, request, pk):
        sba = get_object_or_404(SlotBusAssignment, pk=pk)
        return handle_maker_checker_mutation(request, 'slot_assignment', 'delete', entity_id=pk, instance=sba)
