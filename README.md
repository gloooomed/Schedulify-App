<p align="center">
  <img src="assets/images/schedulify_logo_1779400589167.png" alt="Schedulify Logo" width="96" height="96" style="border-radius: 12px;" />
</p>

<h1 align="center">Schedulify</h1>

<p align="center">
  College attendance and timetable management - built for real institutions.
</p>

<p align="center">
  <a href="https://github.com/gloooomed/Schedulify-App/issues/new?labels=bug">Report Bug</a>
  ·
  <a href="https://github.com/gloooomed/Schedulify-App/issues/new?labels=enhancement">Request Feature</a>
</p>

<p align="center">
  <a href="https://github.com/gloooomed/Schedulify-App/stargazers">
    <img src="https://img.shields.io/github/stars/gloooomed/Schedulify-App?style=for-the-badge&labelColor=0A0F1E&color=3B82F6&label=STARS" alt="Stars" />
  </a>
  <a href="https://github.com/gloooomed/Schedulify-App/forks">
    <img src="https://img.shields.io/github/forks/gloooomed/Schedulify-App?style=for-the-badge&labelColor=0A0F1E&color=3B82F6&label=FORKS" alt="Forks" />
  </a>
  <a href="#">
    <img src="https://img.shields.io/badge/VERSION-0.2.2-3B82F6?style=for-the-badge&labelColor=0A0F1E" alt="Version" />
  </a>
  <a href="#">
    <img src="https://img.shields.io/badge/PLATFORM-Android%20|%20iOS%20|%20Web-8B5CF6?style=for-the-badge&labelColor=0A0F1E" alt="Platform" />
  </a>
  <a href="#">
    <img src="https://img.shields.io/badge/STATUS-Active-10B981?style=for-the-badge&labelColor=0A0F1E" alt="Status" />
  </a>
</p>

---

## What it does

Schedulify is a closed-source mobile application built for colleges to manage timetables and track student attendance using GPS-enforced, QR-based check-ins.

- **Admin** - Onboard a new college in 5 steps - no backend setup required. Manage departments, courses, classrooms, faculty, and students. Upload or AI-parse timetable data from CSV/text. Draw a geofence polygon on a live map to define the campus boundary. View live attendance sessions and audit logs.
- **Faculty** - See daily schedule and today's classes. Start an attendance session - a rotating QR code is displayed for students to scan. End the session and view the attendance record.
- **Student** - View enrolled courses and weekly timetable. Mark attendance by scanning the faculty's QR code. Location is verified against the campus geofence before the scanner opens. Attendance history is visible per course.

---

## Architecture

- **Multi-tenant** - each college has its own isolated Supabase project. A central vendor registry maps college IDs to credentials.
- **GPS-enforced attendance** - geofence is drawn by the admin. Students outside the boundary cannot open the scanner. Mock GPS is rejected.
- **Rotating QR hashes** - the QR code changes every 5 seconds using a deterministic SHA-256 hash shared between the app and the Supabase RPC. Screenshot sharing cannot be used for proxy attendance.
- **Role-based routing** - admin, faculty, and student each land on a separate dashboard with isolated permissions.

---

## Tech Stack

| Category | Technology |
|---|---|
| Framework | [![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev) [![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev) |
| State Management | [![Riverpod](https://img.shields.io/badge/Riverpod-00BCD4?style=for-the-badge&logo=dart&logoColor=white)](https://riverpod.dev) |
| Navigation | [![GoRouter](https://img.shields.io/badge/GoRouter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://pub.dev/packages/go_router) |
| Backend | [![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com) |
| AI | [![Groq](https://img.shields.io/badge/Groq_LLaMA-F55036?style=for-the-badge&logo=groq&logoColor=white)](https://groq.com) |
| Geofencing | [![Geolocator](https://img.shields.io/badge/Geolocator-1A2235?style=for-the-badge&labelColor=0A0F1E)](https://pub.dev/packages/geolocator) |

---

## Supported Devices

| Platform | Minimum Version | Notes |
|---|---|---|
| Android | Android 5.0 (API 21) | Primary supported platform |
| iOS | iOS 11.0 | Full platform support |
| Web | Modern Browsers | Supported for Admin dashboard |

> GPS and camera permissions are required for attendance marking.

---

## What's New in 0.2.2

- Geofence now **fails closed** - if no polygon is configured, attendance is blocked (previously allowed everyone through)
- GPS buffer changed from a fixed 60 m to a **dynamic accuracy-based buffer** capped at 20 m - matches the device's reported GPS error margin
- Replaced `flutter_barcode_scanner` (abandoned, jcenter-dependent) with `barcode_scan2` (native ZXing, Gradle 9 compatible)
- Fixed Gradle duplicate class error caused by legacy Android support library
- Removed all unnecessary comments from the codebase

---

## Coming in the Next Update

- Student enrollment management from the admin panel
- Attendance analytics dashboard with per-course percentage breakdowns
- Push notifications for session start/end
- Offline grace period for poor connectivity environments

---

<p align="center">
  <em>Built for colleges. Runs on Android, iOS, and Web.</em>
</p>
