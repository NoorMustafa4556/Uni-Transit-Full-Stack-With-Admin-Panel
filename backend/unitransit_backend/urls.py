from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),

    # All API v1 routes
    path('api/v1/', include('accounts.urls')),
    path('api/v1/', include('transit.urls')),
    path('api/v1/', include('schedules.urls')),
    path('api/v1/', include('tracking.urls')),
    path('api/v1/', include('operations.urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
