import os
from django.core.asgi import get_asgi_application
from channels.routing import ProtocolTypeRouter, URLRouter

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'unitransit_backend.settings')

django_asgi_app = get_asgi_application()

from accounts.ws_middleware import JWTAuthMiddleware
import tracking.routing

application = ProtocolTypeRouter({
    "http": django_asgi_app,
    "websocket": JWTAuthMiddleware(
        URLRouter(
            tracking.routing.websocket_urlpatterns
        )
    ),
})
