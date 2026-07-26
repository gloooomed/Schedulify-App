<h1 align="center">
  <img src="assets/images/App_icon.svg" width="80" alt="Schedulify Logo" /><br/>
  Schedulify
</h1>

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
    <img src="https://img.shields.io/badge/VERSION-0.3.0-3B82F6?style=for-the-badge&labelColor=0A0F1E" alt="Version" />
  </a>
  <a href="#">
    <img src="https://img.shields.io/badge/PLATFORM-Android%20|%20Web%20(iOS%20PWA)-8B5CF6?style=for-the-badge&labelColor=0A0F1E" alt="Platform" />
  </a>
  <a href="#">
    <img src="https://img.shields.io/badge/STATUS-Active-10B981?style=for-the-badge&labelColor=0A0F1E" alt="Status" />
  </a>
</p>

---

## What it does

Schedulify is a closed-source mobile application built for colleges to manage timetables and track student attendance using GPS-enforced, QR-based check-ins.

- **Admin** - Onboard a new college in 5 steps — no backend setup required. Manage departments, courses, classrooms, faculty, and students. Upload or AI-parse timetable data from CSV/text. Draw a geofence polygon on a live map to define the campus boundary. View live attendance sessions, audit logs, and attendance analytics. Create and manage assignments with file attachments.
- **Faculty** - See daily schedule and today's classes. Start an attendance session — a rotating QR code is displayed for students to scan. End the session and view the attendance record. Create assignments, upload question files, and review student submissions.
- **Student** - View enrolled courses and weekly timetable. Mark attendance by scanning the faculty's QR code. Location is verified against the campus geofence before the scanner opens. Attendance history is visible per course. View and submit assignments.

---

## Architecture

- **Multi-tenant** - each college has its own isolated Supabase project. A central vendor registry maps college IDs to credentials.
- **GPS-enforced attendance** - geofence is drawn by the admin. Students outside the boundary cannot open the scanner. Mock GPS is rejected.
- **Rotating QR hashes** - the QR code changes every 5 seconds using a deterministic SHA-256 hash shared between the app and the Supabase RPC. Screenshot sharing cannot be used for proxy attendance.
- **Role-based routing** - admin, faculty, and student each land on a separate dashboard with isolated permissions.
- **Assignment system** - faculty create assignments with optional file attachments; students submit work; admins have a full overview.
- **Schedule caching** - timetable and course data are cached locally so the schedule loads instantly on subsequent opens.
- **Row-Level Security** - all database tables are protected by RLS policies; students can only see their own data.

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
| Secure Storage | [![flutter_secure_storage](https://img.shields.io/badge/Secure_Storage-1A2235?style=for-the-badge&labelColor=0A0F1E)](https://pub.dev/packages/flutter_secure_storage) |

---

## Supported Devices

| Platform | Minimum Version | Notes |
|---|---|---|
| Android | Android 5.0 (API 21) | Primary supported platform |
| iOS | iOS 14.0+ (Safari) | Supported via Installable PWA |
| Web | Modern Browsers | Supported for Admin dashboard & Students |

> GPS and camera permissions are required for attendance marking.

---

## What's New in 0.3.0

**Assignments**
- Faculty can create assignments and attach question files directly from the app.
- Students can view and submit assignments per course.
- Admins have a full assignment overview across all courses.
- File optimizer compresses uploads before storing to Supabase Storage.

**Performance & PWA**
- Timetable and course data is now cached locally — schedule loads instantly after the first open.
- Attendance analytics added to the admin overview with rate charts and session breakdowns.
- PWA install prompt, offline icons, and improved `manifest.json` for a better installable web experience.
- Supabase initialization flow refactored for more reliable session restoration.

**Security Hardening**
- Row-Level Security (RLS) enabled on all core tables.
- Fixed infinite RLS recursion bug (`42P17`) using a `SECURITY DEFINER` helper function.
- Department-scoped enrollment enforced — students cannot see courses outside their branch.
- Service role key now stored in the device's encrypted keystore (`flutter_secure_storage`).

**Admin Capabilities**
- Admins can delete faculty and student profiles directly from the Users tab.
- Cascade delete cleans up all related enrollments and attendance records automatically.
- Service role key can be entered securely from the admin panel via the 🔑 key icon.

**Bug Fixes**
- Fixed APK build failure caused by a missing `strings.xml` resource file.
- Fixed silent crash in the student dashboard causing blank screens.
- Fixed students not being enrolled when added after a timetable was published.

---

## Coming in the Next Update

- **Real-Time Schedule Alerts:** Push notifications when a professor reschedules a class or changes venue.
- **Interactive Campus Navigation:** Dynamic campus map guiding students to the correct building and room.
- **Study Group Hubs:** In-app space to form study groups and share resources with classmates.

---

<p align="center">
  <em>Built for colleges. Runs on Android, iOS, and Web.</em>
</p>
