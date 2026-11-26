from django.urls import path
from .views import (
    HubListCreateView, HubDetailView,
    RouteCategoryListCreateView, RouteTagListView, GenderCategoryListView,
    StopListCreateView, StopDetailView,
    RouteListCreateView, RouteDetailView, BusListCreateView
)

urlpatterns = [
    path('transit/hubs/', HubListCreateView.as_view(), name='transit-hubs'),
    path('transit/hubs/<int:pk>/', HubDetailView.as_view(), name='transit-hub-detail'),
    path('transit/route-categories/', RouteCategoryListCreateView.as_view(), name='transit-categories'),
    path('transit/route-tags/', RouteTagListView.as_view(), name='transit-tags'),
    path('transit/gender-categories/', GenderCategoryListView.as_view(), name='transit-genders'),
    path('transit/stops/', StopListCreateView.as_view(), name='transit-stops'),
    path('transit/stops/<int:pk>/', StopDetailView.as_view(), name='transit-stop-detail'),
    path('transit/routes/', RouteListCreateView.as_view(), name='transit-routes'),
    path('transit/routes/<int:pk>/', RouteDetailView.as_view(), name='transit-route-detail'),
    path('transit/buses/', BusListCreateView.as_view(), name='transit-buses'),
]
