from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from .models import StudentProfile, DriverProfile
from transit.models import Stop

User = get_user_model()

class StudentProfileSerializer(serializers.ModelSerializer):
    default_stop_name = serializers.CharField(source='default_stop.name', read_only=True)

    class Meta:
        model = StudentProfile
        fields = [
            'id', 'roll_no', 'reg_no', 'department', 'semester',
            'gender', 'default_stop', 'default_stop_name'
        ]


class DriverProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = DriverProfile
        fields = [
            'id', 'cnic', 'license_no', 'license_expiry',
            'experience', 'cnic_front', 'cnic_back', 'license_image', 'duty_status'
        ]


class UserSerializer(serializers.ModelSerializer):
    student_profile = StudentProfileSerializer(read_only=True)
    driver_profile = DriverProfileSerializer(read_only=True)

    class Meta:
        model = User
        fields = [
            'id', 'email', 'name', 'phone', 'role', 'is_verified',
            'is_blocked', 'profile_image', 'fcm_token', 'student_profile', 'driver_profile'
        ]
        read_only_fields = ['id', 'email', 'role', 'is_verified', 'is_blocked']


class RegisterSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)
    name = serializers.CharField(max_length=150)
    phone = serializers.CharField(max_length=20, required=False, allow_blank=True)
    role = serializers.ChoiceField(choices=['student', 'driver'])

    # Student specific fields
    roll_no = serializers.CharField(max_length=50, required=False, allow_blank=True)
    reg_no = serializers.CharField(max_length=50, required=False, allow_blank=True)
    department = serializers.CharField(max_length=100, required=False, allow_blank=True)
    semester = serializers.CharField(max_length=20, required=False, allow_blank=True)
    gender = serializers.ChoiceField(choices=['Male', 'Female', 'Other'], default='Male')
    default_stop_id = serializers.IntegerField(required=False, allow_null=True)

    # Driver specific fields
    cnic = serializers.CharField(max_length=20, required=False, allow_blank=True)
    license_no = serializers.CharField(max_length=50, required=False, allow_blank=True)
    experience = serializers.CharField(max_length=50, required=False, allow_blank=True)

    def validate_email(self, value):
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("A user with this email already exists.")
        return value.lower()

    def create(self, validated_data):
        role = validated_data['role']
        user = User.objects.create_user(
            email=validated_data['email'],
            password=validated_data['password'],
            name=validated_data['name'],
            phone=validated_data.get('phone', ''),
            role=role,
            is_verified=False,  # Needs admin verification by default
        )

        if role == 'student':
            default_stop = None
            stop_id = validated_data.get('default_stop_id')
            if stop_id:
                default_stop = Stop.objects.filter(id=stop_id).first()

            StudentProfile.objects.create(
                user=user,
                roll_no=validated_data.get('roll_no', ''),
                reg_no=validated_data.get('reg_no', ''),
                department=validated_data.get('department', ''),
                semester=validated_data.get('semester', ''),
                gender=validated_data.get('gender', 'Male'),
                default_stop=default_stop,
            )
        elif role == 'driver':
            DriverProfile.objects.create(
                user=user,
                cnic=validated_data.get('cnic', ''),
                license_no=validated_data.get('license_no', ''),
                experience=validated_data.get('experience', ''),
                duty_status='offline',
            )

        return user


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(required=True)
    new_password = serializers.CharField(required=True)

    def validate_new_password(self, value):
        validate_password(value)
        return value


class StatusUpdateSerializer(serializers.Serializer):
    is_verified = serializers.BooleanField(required=False)
    is_blocked = serializers.BooleanField(required=False)


class AdminCreateSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)
    name = serializers.CharField(max_length=150)
    phone = serializers.CharField(max_length=20, required=False, allow_blank=True)
    role = serializers.ChoiceField(choices=['sub_admin', 'super_admin'], default='sub_admin')

    def validate_email(self, value):
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("An admin with this email already exists.")
        return value.lower()

    def create(self, validated_data):
        role = validated_data.get('role', 'sub_admin')
        is_superuser = (role == 'super_admin')
        user = User.objects.create_user(
            email=validated_data['email'],
            password=validated_data['password'],
            name=validated_data['name'],
            phone=validated_data.get('phone', ''),
            role=role,
            is_staff=True,
            is_superuser=is_superuser,
            is_verified=True,
        )
        return user
