from django.db import models
from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.conf import settings

class CustomUserManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError('The Email field must be set')
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        if password:
            user.set_password(password)
        else:
            user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('role', 'super_admin')
        extra_fields.setdefault('is_verified', True)

        if extra_fields.get('is_staff') is not True:
            raise ValueError('Superuser must have is_staff=True.')
        if extra_fields.get('is_superuser') is not True:
            raise ValueError('Superuser must have is_superuser=True.')

        return self.create_user(email, password, **extra_fields)


class User(AbstractUser):
    ROLE_CHOICES = [
        ('student', 'Student'),
        ('driver', 'Driver'),
        ('sub_admin', 'Sub Admin'),
        ('super_admin', 'Super Admin'),
    ]

    username = None  # Using email for authentication
    email = models.EmailField(unique=True)
    name = models.CharField(max_length=150)
    phone = models.CharField(max_length=20, blank=True)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='student')
    is_verified = models.BooleanField(default=False)
    is_blocked = models.BooleanField(default=False)
    profile_image = models.ImageField(upload_to='profiles/', blank=True, null=True)
    fcm_token = models.CharField(max_length=255, blank=True, null=True)

    objects = CustomUserManager()

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['name']

    def __str__(self):
        return f"{self.name} ({self.email}) - {self.get_role_display()}"


class StudentProfile(models.Model):
    GENDER_CHOICES = [
        ('Male', 'Male'),
        ('Female', 'Female'),
        ('Other', 'Other'),
    ]

    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='student_profile')
    roll_no = models.CharField(max_length=50, blank=True)
    reg_no = models.CharField(max_length=50, blank=True)
    department = models.CharField(max_length=100, blank=True)
    semester = models.CharField(max_length=20, blank=True)
    gender = models.CharField(max_length=10, choices=GENDER_CHOICES, default='Male')
    default_stop = models.ForeignKey(
        'transit.Stop',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='default_students'
    )

    def __str__(self):
        return f"Student: {self.user.name} ({self.roll_no or 'No Roll No'})"


class DriverProfile(models.Model):
    DUTY_STATUS_CHOICES = [
        ('online', 'Online'),
        ('offline', 'Offline'),
        ('busy', 'Busy'),
    ]

    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='driver_profile')
    cnic = models.CharField(max_length=20, blank=True)
    license_no = models.CharField(max_length=50, blank=True)
    license_expiry = models.DateField(null=True, blank=True)
    experience = models.CharField(max_length=50, blank=True)
    cnic_front = models.ImageField(upload_to='drivers/cnic/', blank=True, null=True)
    cnic_back = models.ImageField(upload_to='drivers/cnic/', blank=True, null=True)
    license_image = models.ImageField(upload_to='drivers/license/', blank=True, null=True)
    duty_status = models.CharField(max_length=20, choices=DUTY_STATUS_CHOICES, default='offline')

    def __str__(self):
        return f"Driver: {self.user.name} ({self.license_no or 'No License'}) - {self.get_duty_status_display()}"
