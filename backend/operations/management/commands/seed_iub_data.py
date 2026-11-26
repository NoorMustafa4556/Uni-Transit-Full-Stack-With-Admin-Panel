import datetime
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from accounts.models import StudentProfile, DriverProfile
from transit.models import Hub, RouteCategory, RouteTag, GenderCategory, Stop, Route, RouteStop, Bus
from schedules.models import ScheduleProfile, TimeSlot, SlotBusAssignment
from operations.models import TransportContact, Faq, AppConfig

User = get_user_model()

class Command(BaseCommand):
    help = "Seeds initial IUB 2026 Transit data (Hubs, Routes, Stops, Schedules, Contacts, Users)"

    def handle(self, *args, **kwargs):
        self.stdout.write(self.style.NOTICE("--- Starting IUB 2026 Seed Data ---"))

        # 1. Hubs
        hubs_data = [
            {"code": "AC", "name": "Abbasia Campus", "latitude": 29.398233, "longitude": 71.692013},
            {"code": "BJC", "name": "Baghdad-ul-Jadeed Campus", "latitude": 29.378301, "longitude": 71.756057},
            {"code": "KHFC", "name": "Khawaja Fareed / Railway Campus", "latitude": 29.395793, "longitude": 71.662153},
            {"code": "FG", "name": "Fareed Gate", "latitude": 29.399500, "longitude": 71.683600},
        ]
        hubs = {}
        for h in hubs_data:
            obj, _ = Hub.objects.update_or_create(
                code=h["code"],
                defaults={"name": h["name"], "latitude": h["latitude"], "longitude": h["longitude"], "is_active": True}
            )
            hubs[h["code"]] = obj
        self.stdout.write(self.style.SUCCESS(f"Hubs seeded: {len(hubs)}"))

        # 2. Route Categories
        cat_inter, _ = RouteCategory.objects.update_or_create(slug="inter_campus", defaults={"name": "Inter Campus", "is_active": True})
        cat_out, _ = RouteCategory.objects.update_or_create(slug="out_city", defaults={"name": "Out City", "is_active": False})
        cat_shuttle, _ = RouteCategory.objects.update_or_create(slug="shuttle", defaults={"name": "Campus Shuttle", "is_active": True})
        self.stdout.write(self.style.SUCCESS("Route Categories seeded (inter_campus, out_city, shuttle)"))

        # 3. Route Tags
        tags_data = [
            {"code": "S", "label": "Staff Colony", "color_hex": "#4CAF50", "is_active": True},
            {"code": "SB", "label": "School Bus", "color_hex": "#FF9800", "is_active": True},
            {"code": "R", "label": "Rafi Qamar", "color_hex": "#2196F3", "is_active": False},
            {"code": "I", "label": "Islami Colony & Khayaban Ali", "color_hex": "#9C27B0", "is_active": False},
            {"code": "B", "label": "Model Town B & C", "color_hex": "#E91E63", "is_active": False},
        ]
        tags = {}
        for t in tags_data:
            obj, _ = RouteTag.objects.update_or_create(
                code=t["code"],
                defaults={"label": t["label"], "color_hex": t["color_hex"], "is_active": t["is_active"]}
            )
            tags[t["code"]] = obj
        self.stdout.write(self.style.SUCCESS(f"Route Tags seeded: {len(tags)}"))

        # 4. Gender Categories
        g_boys, _ = GenderCategory.objects.update_or_create(name="Boys", defaults={"color_hex": "#1976D2", "is_active": True})
        g_girls, _ = GenderCategory.objects.update_or_create(name="Girls", defaults={"color_hex": "#E91E63", "is_active": True})
        g_comb, _ = GenderCategory.objects.update_or_create(name="Combined", defaults={"color_hex": "#4CAF50", "is_active": True})
        self.stdout.write(self.style.SUCCESS("Gender Categories seeded (Boys, Girls, Combined)"))

        # 5. Core Stops
        stops_data = [
            {"name": "Abbasia Campus", "latitude": 29.398233, "longitude": 71.692013},
            {"name": "Saddar Pully", "latitude": 29.392557, "longitude": 71.692327},
            {"name": "One Unit", "latitude": 29.390194, "longitude": 71.698230},
            {"name": "Shadab Colony", "latitude": 29.388611, "longitude": 71.701660},
            {"name": "Technical Chowk", "latitude": 29.387552, "longitude": 71.703993},
            {"name": "Hussaini Chowk", "latitude": 29.384948, "longitude": 71.709786},
            {"name": "Mela Gali", "latitude": 29.382192, "longitude": 71.716167},
            {"name": "Basheer Wala Phatta", "latitude": 29.379651, "longitude": 71.721799},
            {"name": "10 BC", "latitude": 29.378816, "longitude": 71.728144},
            {"name": "Baghdad Gate", "latitude": 29.381341, "longitude": 71.735779},
            {"name": "Zero Point", "latitude": 29.384381, "longitude": 71.746895},
            {"name": "Baghdad Campus", "latitude": 29.378301, "longitude": 71.756057},
        ]
        created_stops = {}
        for s in stops_data:
            obj, _ = Stop.objects.update_or_create(
                name=s["name"],
                defaults={"latitude": s["latitude"], "longitude": s["longitude"], "geofence_radius_m": 70.0, "is_active": True}
            )
            created_stops[s["name"]] = obj
        self.stdout.write(self.style.SUCCESS(f"Core Stops seeded: {len(created_stops)}"))

        # 6. Routes
        # AC to BJC
        ac_to_bjc, _ = Route.objects.update_or_create(
            name="AC to BJC",
            defaults={
                "origin_hub": hubs["AC"],
                "destination_hub": hubs["BJC"],
                "category": cat_inter,
                "distance_km": 14.5,
                "est_duration_min": 35,
                "is_active": True,
            }
        )

        # BJC to AC
        bjc_to_ac, _ = Route.objects.update_or_create(
            name="BJC to AC",
            defaults={
                "origin_hub": hubs["BJC"],
                "destination_hub": hubs["AC"],
                "category": cat_inter,
                "distance_km": 14.5,
                "est_duration_min": 35,
                "is_active": True,
            }
        )

        # AC to KH. FC
        ac_to_khfc, _ = Route.objects.update_or_create(
            name="AC to KH. FC",
            defaults={
                "origin_hub": hubs["AC"],
                "destination_hub": hubs["KHFC"],
                "category": cat_inter,
                "distance_km": 4.2,
                "est_duration_min": 15,
                "is_active": True,
            }
        )

        # KH. FC to AC
        khfc_to_ac, _ = Route.objects.update_or_create(
            name="KH. FC to AC",
            defaults={
                "origin_hub": hubs["KHFC"],
                "destination_hub": hubs["AC"],
                "category": cat_inter,
                "distance_km": 4.2,
                "est_duration_min": 15,
                "is_active": True,
            }
        )

        # RouteStop records for AC to BJC
        RouteStop.objects.filter(route=ac_to_bjc).delete()
        for idx, stop_name in enumerate(stops_data, start=1):
            avg_min = int((idx - 1) * 3)
            dist_km = round((idx - 1) * 1.2, 1)
            RouteStop.objects.create(
                route=ac_to_bjc,
                stop=created_stops[stop_name["name"]],
                sequence_order=idx,
                avg_min_from_start=avg_min,
                distance_from_start_km=dist_km,
            )
        self.stdout.write(self.style.SUCCESS("Routes & Ordered RouteStops seeded"))

        # 7. Test Users
        # Super Admin
        super_admin, created = User.objects.get_or_create(
            email="admin@unitransit.iub.edu.pk",
            defaults={
                "name": "Super Admin",
                "role": "super_admin",
                "is_verified": True,
                "is_staff": True,
                "is_superuser": True,
            }
        )
        if created or not super_admin.check_password("AdminPassword123!"):
            super_admin.set_password("AdminPassword123!")
            super_admin.save()

        # Sub Admin
        sub_admin, created = User.objects.get_or_create(
            email="subadmin@unitransit.iub.edu.pk",
            defaults={
                "name": "Transport Officer",
                "role": "sub_admin",
                "is_verified": True,
                "is_staff": True,
                "is_superuser": False,
            }
        )
        if created or not sub_admin.check_password("SubAdminPassword123!"):
            sub_admin.set_password("SubAdminPassword123!")
            sub_admin.save()

        # Drivers
        d1_user, created = User.objects.get_or_create(
            email="driver1@unitransit.iub.edu.pk",
            defaults={"name": "Muhammad Aslam", "role": "driver", "is_verified": True, "phone": "0301-1234567"}
        )
        if created:
            d1_user.set_password("Driver123!")
            d1_user.save()
        driver1, _ = DriverProfile.objects.update_or_create(
            user=d1_user,
            defaults={"cnic": "31202-1234567-1", "license_no": "LHR-98745", "experience": "8 years", "duty_status": "online"}
        )

        d2_user, created = User.objects.get_or_create(
            email="driver2@unitransit.iub.edu.pk",
            defaults={"name": "Tariq Mahmood", "role": "driver", "is_verified": True, "phone": "0302-7654321"}
        )
        if created:
            d2_user.set_password("Driver123!")
            d2_user.save()
        driver2, _ = DriverProfile.objects.update_or_create(
            user=d2_user,
            defaults={"cnic": "31202-7654321-3", "license_no": "BWP-45612", "experience": "5 years", "duty_status": "online"}
        )

        # Students
        s1_user, created = User.objects.get_or_create(
            email="student1@unitransit.iub.edu.pk",
            defaults={"name": "Ahmad Raza", "role": "student", "is_verified": True, "phone": "0300-1122334"}
        )
        if created:
            s1_user.set_password("Student123!")
            s1_user.save()
        StudentProfile.objects.update_or_create(
            user=s1_user,
            defaults={
                "roll_no": "FA21-BCS-042",
                "reg_no": "S21-1042",
                "department": "Computer Science",
                "semester": "6th",
                "gender": "Male",
                "default_stop": created_stops["Saddar Pully"],
            }
        )

        s2_user, created = User.objects.get_or_create(
            email="student2@unitransit.iub.edu.pk",
            defaults={"name": "Fatima Noor", "role": "student", "is_verified": True, "phone": "0300-9988776"}
        )
        if created:
            s2_user.set_password("Student123!")
            s2_user.save()
        StudentProfile.objects.update_or_create(
            user=s2_user,
            defaults={
                "roll_no": "SP22-BBA-019",
                "reg_no": "S22-2019",
                "department": "Management Sciences",
                "semester": "4th",
                "gender": "Female",
                "default_stop": created_stops["One Unit"],
            }
        )
        self.stdout.write(self.style.SUCCESS("Test Users (1 Super Admin, 1 Sub Admin, 2 Drivers, 2 Students) seeded"))

        # 8. Buses
        buses_seed = [
            {"bus_number": "1", "plate_number": "BWP-7001", "capacity": 52, "gender": g_boys, "driver": driver1},
            {"bus_number": "2", "plate_number": "BWP-7002", "capacity": 52, "gender": g_girls, "driver": driver2},
            {"bus_number": "18", "plate_number": "BWP-7018", "capacity": 50, "gender": g_comb, "driver": None},
            {"bus_number": "19S", "plate_number": "BWP-7019", "capacity": 50, "gender": g_comb, "driver": None},
            {"bus_number": "SB1", "plate_number": "BWP-7101", "capacity": 40, "gender": g_comb, "driver": None},
            {"bus_number": "31S", "plate_number": "BWP-7031", "capacity": 50, "gender": g_comb, "driver": None},
            {"bus_number": "40", "plate_number": "BWP-7040", "capacity": 55, "gender": g_comb, "driver": None},
        ]
        buses = {}
        for b in buses_seed:
            obj, _ = Bus.objects.update_or_create(
                bus_number=b["bus_number"],
                defaults={
                    "plate_number": b["plate_number"],
                    "capacity": b["capacity"],
                    "default_gender": b["gender"],
                    "assigned_driver": b["driver"],
                    "status": "active",
                }
            )
            buses[b["bus_number"]] = obj
        self.stdout.write(self.style.SUCCESS(f"Buses seeded: {len(buses)} (1, 2, 18, 19S, SB1, 31S, 40)"))

        # 9. ScheduleProfile
        profile, _ = ScheduleProfile.objects.update_or_create(
            name="During Examinations (w.e.f 12.01.2026)",
            defaults={"effective_from": datetime.date(2026, 1, 12), "is_active": True}
        )

        # Clear existing slots under this profile for idempotency
        TimeSlot.objects.filter(profile=profile).delete()

        # Morning slots (AC to BJC)
        morning_slots = [
            (datetime.time(7, 0), "weekday", [(buses["1"], g_boys, []), (buses["2"], g_girls, []), (buses["18"], g_comb, [])]),
            (datetime.time(8, 0), "weekday", [(buses["19S"], g_comb, [tags["S"]]), (buses["SB1"], g_comb, [tags["SB"]]), (buses["31S"], g_comb, [tags["S"]])]),
            (datetime.time(9, 0), "weekday", [(buses["40"], g_comb, [])]),
            # Evening slots (BJC to AC)
            (datetime.time(16, 30), "weekday", [(buses["1"], g_boys, []), (buses["2"], g_girls, [])]),
            (datetime.time(17, 30), "weekday", [(buses["18"], g_comb, []), (buses["40"], g_comb, [])]),
            # Saturday / Offday (AC to BJC)
            (datetime.time(8, 0), "saturday_offday", [(buses["1"], g_boys, [])]),
            (datetime.time(9, 0), "saturday_offday", [(buses["2"], g_girls, [])]),
        ]

        for dep_time, day_type, assignments in morning_slots:
            shift = "evening" if dep_time.hour >= 16 else "morning"
            route = bjc_to_ac if shift == "evening" else ac_to_bjc
            slot = TimeSlot.objects.create(
                profile=profile,
                route=route,
                shift=shift,
                day_type=day_type,
                departure_time=dep_time,
                is_active=True,
            )
            for order, (bus_obj, gender_obj, tag_list) in enumerate(assignments, start=1):
                sba = SlotBusAssignment.objects.create(
                    time_slot=slot,
                    bus=bus_obj,
                    driver=bus_obj.assigned_driver,
                    gender=gender_obj,
                    dispatch_order=order,
                    is_active=True,
                )
                if tag_list:
                    sba.tags.set(tag_list)

        self.stdout.write(self.style.SUCCESS("Schedule Profile & SlotBusAssignments seeded"))

        # 10. Transport Contacts
        contacts_data = [
            {"shift": "Morning", "route_scope": "AC to BJC / KHFC", "phone_number": "0349-4417157", "is_whatsapp": False},
            {"shift": "Morning", "route_scope": "BJC to AC", "phone_number": "0306-8153213", "is_whatsapp": False},
            {"shift": "Evening", "route_scope": "AC to BJC / KHFC", "phone_number": "0303-8742694", "is_whatsapp": False},
            {"shift": "Evening", "route_scope": "BJC to AC", "phone_number": "0308-2511630", "is_whatsapp": False},
            {"shift": "General", "route_scope": "Transport Complaint Helpline", "phone_number": "0300-6809094", "is_whatsapp": True},
        ]
        for c in contacts_data:
            TransportContact.objects.update_or_create(
                route_scope=c["route_scope"],
                shift=c["shift"],
                defaults={"phone_number": c["phone_number"], "is_whatsapp": c["is_whatsapp"], "is_active": True}
            )
        self.stdout.write(self.style.SUCCESS("Transport Contacts seeded (2026 IUB Schedule)"))

        # 11. FAQ & AppConfig
        faqs = [
            ("How do I track my bus?", "Open the UniTransit mobile app, tap 'Live Map' or select your active route to view real-time location.", "Tracking"),
            ("What are the exam bus timings?", "Morning routes depart at 7:00 AM, 8:00 AM, and 9:00 AM. Evening departures are at 4:30 PM and 5:30 PM.", "Schedule"),
            ("How can I contact transport staff?", "Call the dispatchers listed in the Contacts screen or message the official WhatsApp at 0300-6809094.", "Support"),
        ]
        for idx, (q, a, cat) in enumerate(faqs, start=1):
            Faq.objects.update_or_create(
                question=q,
                defaults={"answer": a, "category": cat, "order": idx, "is_active": True}
            )

        AppConfig.objects.update_or_create(
            pk=1,
            defaults={
                "app_name": "UniTransit",
                "tagline": "IUB Smart University Bus Tracking System",
                "university": "The Islamia University of Bahawalpur",
                "version": "1.0.0",
                "complaint_whatsapp": "0300-6809094",
                "primary_color": "#1E88E5",
                "accent_color": "#FFC107",
            }
        )
        self.stdout.write(self.style.SUCCESS("AppConfig & FAQs initialized"))
        self.stdout.write(self.style.SUCCESS("=== SEEDING COMPLETED SUCCESSFULLY ==="))
