<h1 align="center">Schedulify</h1>

<p align="center">
  College attendance and timetable management — built for real institutions.
</p>

<p align="center">
  <a href="#">
    <img src="https://img.shields.io/badge/VERSION-0.2.2-3B82F6?style=for-the-badge&labelColor=0A0F1E" alt="Version" />
  </a>
  <a href="#">
    <img src="https://img.shields.io/badge/PLATFORM-Android-8B5CF6?style=for-the-badge&labelColor=0A0F1E" alt="Platform" />
  </a>
  <a href="#">
    <img src="https://img.shields.io/badge/STATUS-Active-10B981?style=for-the-badge&labelColor=0A0F1E" alt="Status" />
  </a>
</p>

---

## Screenshots

<p align="center">
  <img src="assets/images/Screenshot 2026-05-22 033014.png" alt="Schedulify Gateway Screen" width="45%" />
  &nbsp;&nbsp;
  <img src="assets/images/Screenshot 2026-05-22 033021.png" alt="Schedulify Admin Dashboard" width="45%" />
</p>

---

## What it does

Schedulify is a closed-source mobile application built for colleges to manage timetables and track student attendance using GPS-enforced, QR-based check-ins.

**Admin**
- Onboard a new college in 5 steps — no backend setup required
- Manage departments, courses, classrooms, faculty, and students
- Upload or AI-parse timetable data from CSV/text
- Draw a geofence polygon on a live map to define the campus boundary
- View live attendance sessions and audit logs

**Faculty**
- See daily schedule and today's classes
- Start an attendance session — a rotating QR code is displayed for students to scan
- End the session and view the attendance record

**Student**
- View enrolled courses and weekly timetable
- Mark attendance by scanning the faculty's QR code
- Location is verified against the campus geofence before the scanner opens
- Attendance history is visible per course

---

## Supported Devices

| Platform | Minimum Version | Notes |
|---|---|---|
| Android | Android 5.0 (API 21) | Primary supported platform |
| iOS | Not yet supported | Planned for a future release |

> GPS and camera permissions are required for attendance marking.

---

## Tech Stack

| Category | Technology |
|---|---|
| Framework | Flutter · Dart |
| State Management | Riverpod |
| Navigation | GoRouter |
| Backend | Supabase (per-college isolated projects) |
| AI Parsing | Groq LLaMA |
| QR Scanning | barcode_scan2 (native ZXing) |
| Geofencing | geolocator · maps_toolkit |
| Animations | flutter_animate |

---

## Architecture

- **Multi-tenant** — each college has its own isolated Supabase project. A central vendor registry maps college IDs to credentials.
- **GPS-enforced attendance** — geofence is drawn by the admin. Students outside the boundary cannot open the scanner. Mock GPS is rejected.
- **Rotating QR hashes** — the QR code changes every 5 seconds using a deterministic SHA-256 hash shared between the app and the Supabase RPC. Screenshot sharing cannot be used for proxy attendance.
- **Role-based routing** — admin, faculty, and student each land on a separate dashboard with isolated permissions.

---

## What's New in 0.2.2

- Geofence now **fails closed** — if no polygon is configured, attendance is blocked (previously allowed everyone through)
- GPS buffer changed from a fixed 60 m to a **dynamic accuracy-based buffer** capped at 20 m — matches the device's reported GPS error margin
- Replaced `flutter_barcode_scanner` (abandoned, jcenter-dependent) with `barcode_scan2` (native ZXing, Gradle 9 compatible)
- Fixed Gradle duplicate class error caused by legacy Android support library
- Removed all unnecessary comments from the codebase

---

## Coming in the Next Update

- iOS support
- Student enrollment management from the admin panel
- Attendance analytics dashboard with per-course percentage breakdowns
- Push notifications for session start/end
- Offline grace period for poor connectivity environments

---

<p align="center">
  <em>Built for colleges. Runs on Android.</em>
</p>
