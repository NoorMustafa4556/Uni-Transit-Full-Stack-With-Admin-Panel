from urllib.parse import parse_qs
from channels.db import database_sync_to_async
from django.contrib.auth import get_user_model
from django.contrib.auth.models import AnonymousUser
from rest_framework_simplejwt.tokens import AccessToken

User = get_user_model()

@database_sync_to_async
def get_user_from_jwt(token_str):
    try:
        access_token = AccessToken(token_str)
        user_id = access_token.get('user_id')
        if not user_id:
            return AnonymousUser()
        user = User.objects.filter(id=user_id, is_active=True).select_related('driver_profile', 'student_profile').first()
        if not user or user.is_blocked:
            return AnonymousUser()
        return user
    except Exception:
        return AnonymousUser()


class JWTAuthMiddleware:
    """
    Custom ASGI middleware to authenticate WebSocket connections using JWT passed in the query string:
    ws://domain/ws/route/1/?token=<jwt_access_token>
    """
    def __init__(self, inner):
        self.inner = inner

    async def __call__(self, scope, receive, send):
        query_string = scope.get('query_string', b'').decode('utf-8')
        query_params = parse_qs(query_string)
        token_list = query_params.get('token')

        if token_list:
            token = token_list[0]
            scope['user'] = await get_user_from_jwt(token)
        else:
            scope['user'] = AnonymousUser()

        return await self.inner(scope, receive, send)


def JWTAuthMiddlewareStack(inner):
    return JWTAuthMiddleware(inner)
