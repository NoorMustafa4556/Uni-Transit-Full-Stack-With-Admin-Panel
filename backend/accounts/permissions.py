from rest_framework import permissions

class IsNotBlocked(permissions.BasePermission):
    message = "Your account has been blocked. Please contact the administrator."

    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and not request.user.is_blocked)


class IsStudent(permissions.BasePermission):
    message = "Only active students can access this endpoint."

    def has_permission(self, request, view):
        return bool(
            request.user and
            request.user.is_authenticated and
            not request.user.is_blocked and
            request.user.role == 'student'
        )


class IsVerifiedDriver(permissions.BasePermission):
    message = "Only verified drivers can access this endpoint."

    def has_permission(self, request, view):
        return bool(
            request.user and
            request.user.is_authenticated and
            not request.user.is_blocked and
            request.user.role == 'driver' and
            request.user.is_verified
        )


class IsAdminStaff(permissions.BasePermission):
    message = "Admin staff access required."

    def has_permission(self, request, view):
        return bool(
            request.user and
            request.user.is_authenticated and
            not request.user.is_blocked and
            request.user.role in ['sub_admin', 'super_admin']
        )


class IsSuperAdmin(permissions.BasePermission):
    message = "Super Admin access required."

    def has_permission(self, request, view):
        return bool(
            request.user and
            request.user.is_authenticated and
            not request.user.is_blocked and
            request.user.role == 'super_admin'
        )
