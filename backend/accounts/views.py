from rest_framework import status, views, permissions
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import authenticate, get_user_model
from django.shortcuts import get_object_or_404
from .models import StudentProfile, DriverProfile
from .serializers import (
    UserSerializer, RegisterSerializer, LoginSerializer,
    ChangePasswordSerializer, StatusUpdateSerializer, AdminCreateSerializer
)
from .permissions import IsNotBlocked, IsAdminStaff, IsSuperAdmin
from transit.models import Stop

User = get_user_model()

class RegisterView(views.APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            refresh = RefreshToken.for_user(user)
            return Response({
                'message': 'Registration successful. Account pending admin verification.',
                'tokens': {
                    'refresh': str(refresh),
                    'access': str(refresh.access_token),
                },
                'user': UserSerializer(user).data
            }, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class LoginView(views.APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        email = serializer.validated_data['email'].lower()
        password = serializer.validated_data['password']

        user = User.objects.filter(email__iexact=email).first()
        if not user or not user.check_password(password):
            return Response({'detail': 'Invalid email or password.'}, status=status.HTTP_401_UNAUTHORIZED)

        if user.is_blocked:
            return Response(
                {'detail': 'Your account has been blocked by the administration. Contact support.'},
                status=status.HTTP_403_FORBIDDEN
            )

        refresh = RefreshToken.for_user(user)
        return Response({
            'tokens': {
                'refresh': str(refresh),
                'access': str(refresh.access_token),
            },
            'user': UserSerializer(user).data
        }, status=status.HTTP_200_OK)


class MeView(views.APIView):
    permission_classes = [permissions.IsAuthenticated, IsNotBlocked]

    def get(self, request):
        serializer = UserSerializer(request.user)
        return Response(serializer.data)

    def patch(self, request):
        user = request.user
        data = request.data

        # Update basic user info
        for field in ['name', 'phone']:
            if field in data:
                setattr(user, field, data[field])

        if 'profile_image' in request.FILES:
            user.profile_image = request.FILES['profile_image']

        user.save()

        # Update role-specific profile
        if user.role == 'student' and hasattr(user, 'student_profile'):
            profile = user.student_profile
            for field in ['roll_no', 'reg_no', 'department', 'semester', 'gender']:
                if field in data:
                    setattr(profile, field, data[field])
            if 'default_stop_id' in data:
                stop_id = data['default_stop_id']
                profile.default_stop = Stop.objects.filter(id=stop_id).first() if stop_id else None
            profile.save()

        elif user.role == 'driver' and hasattr(user, 'driver_profile'):
            profile = user.driver_profile
            for field in ['cnic', 'license_no', 'experience', 'duty_status']:
                if field in data:
                    setattr(profile, field, data[field])
            for img in ['cnic_front', 'cnic_back', 'license_image']:
                if img in request.FILES:
                    setattr(profile, img, request.FILES[img])
            profile.save()

        return Response(UserSerializer(user).data)


class FcmTokenView(views.APIView):
    permission_classes = [permissions.IsAuthenticated, IsNotBlocked]

    def post(self, request):
        token = request.data.get('fcm_token')
        if not token:
            return Response({'detail': 'fcm_token is required'}, status=status.HTTP_400_BAD_REQUEST)
        request.user.fcm_token = token
        request.user.save(update_fields=['fcm_token'])
        return Response({'message': 'FCM token updated successfully.'})


class ChangePasswordView(views.APIView):
    permission_classes = [permissions.IsAuthenticated, IsNotBlocked]

    def post(self, request):
        serializer = ChangePasswordSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        user = request.user
        if not user.check_password(serializer.validated_data['old_password']):
            return Response({'old_password': ['Wrong password.']}, status=status.HTTP_400_BAD_REQUEST)

        user.set_password(serializer.validated_data['new_password'])
        user.save()
        return Response({'message': 'Password changed successfully.'})


# --- Admin Endpoints ---

class AdminStudentListView(views.APIView):
    permission_classes = [IsAdminStaff]

    def get(self, request):
        students = User.objects.filter(role='student').select_related('student_profile').order_by('-date_joined')
        department = request.query_params.get('department')
        if department:
            students = students.filter(student_profile__department__icontains=department)
        serializer = UserSerializer(students, many=True)
        return Response(serializer.data)


class AdminStudentStatusView(views.APIView):
    permission_classes = [IsAdminStaff]

    def patch(self, request, pk):
        student = get_object_or_404(User, pk=pk, role='student')
        serializer = StatusUpdateSerializer(data=request.data)
        if serializer.is_valid():
            if 'is_verified' in serializer.validated_data:
                student.is_verified = serializer.validated_data['is_verified']
            if 'is_blocked' in serializer.validated_data:
                student.is_blocked = serializer.validated_data['is_blocked']
            student.save()
            return Response(UserSerializer(student).data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class AdminDriverListCreateView(views.APIView):
    permission_classes = [IsAdminStaff]

    def get(self, request):
        drivers = User.objects.filter(role='driver').select_related('driver_profile').order_by('-date_joined')
        serializer = UserSerializer(drivers, many=True)
        return Response(serializer.data)

    def post(self, request):
        data = request.data.copy()
        data['role'] = 'driver'
        serializer = RegisterSerializer(data=data)
        if serializer.is_valid():
            driver_user = serializer.save()
            driver_user.is_verified = True  # Admins creating driver directly verifies them
            driver_user.save()
            return Response(UserSerializer(driver_user).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class AdminDriverStatusView(views.APIView):
    permission_classes = [IsAdminStaff]

    def patch(self, request, pk):
        driver = get_object_or_404(User, pk=pk, role='driver')
        serializer = StatusUpdateSerializer(data=request.data)
        if serializer.is_valid():
            if 'is_verified' in serializer.validated_data:
                driver.is_verified = serializer.validated_data['is_verified']
            if 'is_blocked' in serializer.validated_data:
                driver.is_blocked = serializer.validated_data['is_blocked']
            driver.save()
            return Response(UserSerializer(driver).data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class AdminManagementView(views.APIView):
    permission_classes = [IsSuperAdmin]

    def get(self, request):
        admins = User.objects.filter(role__in=['sub_admin', 'super_admin']).order_by('-date_joined')
        serializer = UserSerializer(admins, many=True)
        return Response(serializer.data)

    def post(self, request):
        serializer = AdminCreateSerializer(data=request.data)
        if serializer.is_valid():
            admin_user = serializer.save()
            return Response(UserSerializer(admin_user).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
