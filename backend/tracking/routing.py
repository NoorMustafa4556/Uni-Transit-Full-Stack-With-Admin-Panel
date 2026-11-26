from django.urls import re_path
from . import consumers

websocket_urlpatterns = [
    re_path(r'^ws/driver/trip/(?P<trip_id>\d+)/$', consumers.DriverTripConsumer.as_asgi()),
    re_path(r'^ws/route/(?P<route_id>\d+)/$', consumers.RouteTrackingConsumer.as_asgi()),
    re_path(r'^ws/admin/fleet/$', consumers.AdminFleetConsumer.as_asgi()),
]
