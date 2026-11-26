from rest_framework import views, permissions, status
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from .models import Hub, RouteCategory, RouteTag, GenderCategory, Stop, Route, RouteStop, Bus
from .serializers import (
    HubSerializer, RouteCategorySerializer, RouteTagSerializer,
    GenderCategorySerializer, StopSerializer, RouteSerializer, BusSerializer
)
from accounts.permissions import IsNotBlocked, IsAdminStaff
from operations.maker_checker import handle_maker_checker_mutation

def get_filtered_queryset(model_class, request):
    qs = model_class.objects.all()
    include_inactive = request.query_params.get('include_inactive', 'false').lower() == 'true'
    is_admin = bool(request.user and request.user.is_authenticated and request.user.role in ['sub_admin', 'super_admin'])
    if not (is_admin and include_inactive):
        qs = qs.filter(is_active=True)
    return qs


class HubListCreateView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [permissions.AllowAny()]
        return [IsAdminStaff()]

    def get(self, request):
        hubs = get_filtered_queryset(Hub, request)
        return Response(HubSerializer(hubs, many=True).data)

    def post(self, request):
        return handle_maker_checker_mutation(request, 'hub', 'create', serializer_class=HubSerializer)


class HubDetailView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [permissions.AllowAny()]
        return [IsAdminStaff()]

    def get(self, request, pk):
        hub = get_object_or_404(Hub, pk=pk)
        return Response(HubSerializer(hub).data)

    def put(self, request, pk):
        hub = get_object_or_404(Hub, pk=pk)
        return handle_maker_checker_mutation(request, 'hub', 'update', entity_id=pk, serializer_class=HubSerializer, instance=hub)

    def patch(self, request, pk):
        hub = get_object_or_404(Hub, pk=pk)
        return handle_maker_checker_mutation(request, 'hub', 'patch', entity_id=pk, serializer_class=HubSerializer, instance=hub)

    def delete(self, request, pk):
        hub = get_object_or_404(Hub, pk=pk)
        return handle_maker_checker_mutation(request, 'hub', 'delete', entity_id=pk, instance=hub)


class RouteCategoryListCreateView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [permissions.AllowAny()]
        return [IsAdminStaff()]

    def get(self, request):
        categories = get_filtered_queryset(RouteCategory, request)
        return Response(RouteCategorySerializer(categories, many=True).data)

    def post(self, request):
        return handle_maker_checker_mutation(request, 'route_category', 'create', serializer_class=RouteCategorySerializer)


class RouteCategoryDetailView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [permissions.AllowAny()]
        return [IsAdminStaff()]

    def get(self, request, pk):
        category = get_object_or_404(RouteCategory, pk=pk)
        return Response(RouteCategorySerializer(category).data)

    def put(self, request, pk):
        category = get_object_or_404(RouteCategory, pk=pk)
        return handle_maker_checker_mutation(request, 'route_category', 'update', entity_id=pk, serializer_class=RouteCategorySerializer, instance=category)

    def patch(self, request, pk):
        category = get_object_or_404(RouteCategory, pk=pk)
        return handle_maker_checker_mutation(request, 'route_category', 'patch', entity_id=pk, serializer_class=RouteCategorySerializer, instance=category)

    def delete(self, request, pk):
        category = get_object_or_404(RouteCategory, pk=pk)
        return handle_maker_checker_mutation(request, 'route_category', 'delete', entity_id=pk, instance=category)


class RouteTagListView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [permissions.AllowAny()]
        return [IsAdminStaff()]

    def get(self, request):
        tags = get_filtered_queryset(RouteTag, request)
        return Response(RouteTagSerializer(tags, many=True).data)

    def post(self, request):
        return handle_maker_checker_mutation(request, 'route_tag', 'create', serializer_class=RouteTagSerializer)


class RouteTagDetailView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [permissions.AllowAny()]
        return [IsAdminStaff()]

    def get(self, request, pk):
        tag = get_object_or_404(RouteTag, pk=pk)
        return Response(RouteTagSerializer(tag).data)

    def put(self, request, pk):
        tag = get_object_or_404(RouteTag, pk=pk)
        return handle_maker_checker_mutation(request, 'route_tag', 'update', entity_id=pk, serializer_class=RouteTagSerializer, instance=tag)

    def patch(self, request, pk):
        tag = get_object_or_404(RouteTag, pk=pk)
        return handle_maker_checker_mutation(request, 'route_tag', 'patch', entity_id=pk, serializer_class=RouteTagSerializer, instance=tag)

    def delete(self, request, pk):
        tag = get_object_or_404(RouteTag, pk=pk)
        return handle_maker_checker_mutation(request, 'route_tag', 'delete', entity_id=pk, instance=tag)


class GenderCategoryListView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [permissions.AllowAny()]
        return [IsAdminStaff()]

    def get(self, request):
        genders = get_filtered_queryset(GenderCategory, request)
        return Response(GenderCategorySerializer(genders, many=True).data)

    def post(self, request):
        return handle_maker_checker_mutation(request, 'gender_category', 'create', serializer_class=GenderCategorySerializer)


class GenderCategoryDetailView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [permissions.AllowAny()]
        return [IsAdminStaff()]

    def get(self, request, pk):
        gender = get_object_or_404(GenderCategory, pk=pk)
        return Response(GenderCategorySerializer(gender).data)

    def put(self, request, pk):
        gender = get_object_or_404(GenderCategory, pk=pk)
        return handle_maker_checker_mutation(request, 'gender_category', 'update', entity_id=pk, serializer_class=GenderCategorySerializer, instance=gender)

    def patch(self, request, pk):
        gender = get_object_or_404(GenderCategory, pk=pk)
        return handle_maker_checker_mutation(request, 'gender_category', 'patch', entity_id=pk, serializer_class=GenderCategorySerializer, instance=gender)

    def delete(self, request, pk):
        gender = get_object_or_404(GenderCategory, pk=pk)
        return handle_maker_checker_mutation(request, 'gender_category', 'delete', entity_id=pk, instance=gender)


class StopListCreateView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [permissions.AllowAny()]
        return [IsAdminStaff()]

    def get(self, request):
        stops = get_filtered_queryset(Stop, request)
        search = request.query_params.get('search')
        if search:
            stops = stops.filter(name__icontains=search)
        return Response(StopSerializer(stops, many=True).data)

    def post(self, request):
        return handle_maker_checker_mutation(request, 'stop', 'create', serializer_class=StopSerializer)


class StopDetailView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [permissions.AllowAny()]
        return [IsAdminStaff()]

    def get(self, request, pk):
        stop = get_object_or_404(Stop, pk=pk)
        return Response(StopSerializer(stop).data)

    def put(self, request, pk):
        stop = get_object_or_404(Stop, pk=pk)
        return handle_maker_checker_mutation(request, 'stop', 'update', entity_id=pk, serializer_class=StopSerializer, instance=stop)

    def patch(self, request, pk):
        stop = get_object_or_404(Stop, pk=pk)
        return handle_maker_checker_mutation(request, 'stop', 'patch', entity_id=pk, serializer_class=StopSerializer, instance=stop)

    def delete(self, request, pk):
        stop = get_object_or_404(Stop, pk=pk)
        return handle_maker_checker_mutation(request, 'stop', 'delete', entity_id=pk, instance=stop)


class RouteListCreateView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [permissions.AllowAny()]
        return [IsAdminStaff()]

    def get(self, request):
        routes = get_filtered_queryset(Route, request).select_related(
            'origin_hub', 'destination_hub', 'category'
        ).prefetch_related('route_stops__stop')
        category_slug = request.query_params.get('category')
        if category_slug:
            routes = routes.filter(category__slug=category_slug)
        return Response(RouteSerializer(routes, many=True).data)

    def post(self, request):
        return handle_maker_checker_mutation(request, 'route', 'create', serializer_class=RouteSerializer)


class RouteDetailView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [permissions.AllowAny()]
        return [IsAdminStaff()]

    def get(self, request, pk):
        route = get_object_or_404(
            Route.objects.select_related('origin_hub', 'destination_hub', 'category').prefetch_related('route_stops__stop'),
            pk=pk
        )
        return Response(RouteSerializer(route).data)

    def put(self, request, pk):
        route = get_object_or_404(Route, pk=pk)
        return handle_maker_checker_mutation(request, 'route', 'update', entity_id=pk, serializer_class=RouteSerializer, instance=route)

    def patch(self, request, pk):
        route = get_object_or_404(Route, pk=pk)
        return handle_maker_checker_mutation(request, 'route', 'patch', entity_id=pk, serializer_class=RouteSerializer, instance=route)

    def delete(self, request, pk):
        route = get_object_or_404(Route, pk=pk)
        return handle_maker_checker_mutation(request, 'route', 'delete', entity_id=pk, instance=route)


class BusListCreateView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [permissions.AllowAny()]
        return [IsAdminStaff()]

    def get(self, request):
        buses = Bus.objects.select_related('default_gender', 'assigned_driver__user').all()
        status_param = request.query_params.get('status')
        if status_param:
            buses = buses.filter(status=status_param)
        return Response(BusSerializer(buses, many=True).data)

    def post(self, request):
        return handle_maker_checker_mutation(request, 'bus', 'create', serializer_class=BusSerializer)


class BusDetailView(views.APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [permissions.AllowAny()]
        return [IsAdminStaff()]

    def get(self, request, pk):
        bus = get_object_or_404(Bus.objects.select_related('default_gender', 'assigned_driver__user'), pk=pk)
        return Response(BusSerializer(bus).data)

    def put(self, request, pk):
        bus = get_object_or_404(Bus, pk=pk)
        return handle_maker_checker_mutation(request, 'bus', 'update', entity_id=pk, serializer_class=BusSerializer, instance=bus)

    def patch(self, request, pk):
        bus = get_object_or_404(Bus, pk=pk)
        return handle_maker_checker_mutation(request, 'bus', 'patch', entity_id=pk, serializer_class=BusSerializer, instance=bus)

    def delete(self, request, pk):
        bus = get_object_or_404(Bus, pk=pk)
        return handle_maker_checker_mutation(request, 'bus', 'delete', entity_id=pk, instance=bus)
