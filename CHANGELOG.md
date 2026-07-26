# Changelog

All notable changes to Schedulify are documented here.

## [0.3.0] - 2026-07-26

### Added
- **Assignment & Submission System**: Full assignment lifecycle for admin, faculty, and students — create, submit, grade, and review assignments with per-course scoping.
- **Professor File Upload**: Faculty can attach question files to assignments; file optimizer compresses uploads before storing to Supabase Storage.
- **Schedule Caching**: Added a `CacheService` to persist timetable and course data locally, reducing cold-start latency and enabling offline schedule viewing.
- **Attendance Analytics**: Admin overview tab now includes attendance rate charts and per-session breakdowns.
- **PWA Installation Improvements**: Improved `web/index.html` and `manifest.json` with install prompt, icons, and better offline support.
- **Admin delete user**: Removes profile, enrollments, and auth record via Supabase Admin API.
- **Service role key UI**: 🔑 key icon in admin top bar; key stored in encrypted device keystore.
- **Auto-enrollment triggers**: New students enroll in all department courses on profile creation; re-enrolls on department change; new courses auto-enroll all existing department students.
- **Cascade delete**: FK constraints updated with `ON DELETE CASCADE` so deleting a profile cleans up all related rows.

### Changed
- **Supabase initialization refactor**: Improved initialization flow and session restoration in `supabase_client.dart` and `main.dart`.
- **UI standardization**: Refreshed navigation icons and standardized user profile headers across admin, faculty, and student dashboards.
- `mark_attendance` RPC: server-side enrollment check + ±5-second clock skew tolerance.
- `publishTimetable` now uses an atomic RPC to prevent partial write failures.
- `createUser` detects orphaned auth users and auto-removes them before retry.
- Service role key moved from `SharedPreferences` to `flutter_secure_storage`.

### Security
- RLS enabled on all core tables: `profiles`, `courses`, `student_enrollments`, `attendance_sessions`, `attendance_records`.
- Fixed infinite RLS recursion bug (`42P17`) using a `SECURITY DEFINER` helper `get_my_role()`.
- Department-scoped enrollment enforced at DB level — students cannot access courses outside their branch.
- Mock/spoofed GPS explicitly rejected by the `mark_attendance` server function.

### Fixed
- APK build failure caused by missing `strings.xml` Android resource file.
- Silent error swallowing in student dashboard that caused blank course/schedule screens.
- Students created after timetable publication were not getting enrolled in any courses.
- `fileOptions` import inconsistency in assignment service causing sync issues across portals.

## [0.2.4] - 2026-06-15
### Added
- Fully migrated app iconography to crisp SVG formats
- Implemented robust light/dark mode drawer theming
- Fixed browser favicon and native splash screen assets

## [0.2.2] - 2026-06-14
### Changed
- Redesigned dual-logo login screen header with transparent assets
- Stabilized Android build pipeline by moving Firebase config to Dart Defines
- Removed legacy Google Services dependencies
- Complete UI theme parity to fix `const_eval` warnings

## [0.2.0] - 2026-05-22
### Added
- Multi-tenant Supabase architecture with dynamic client switching
- College ID gateway screen with vendor registry lookup
- 5-step onboarding setup wizard for new college configuration
- Role-based authentication (super_admin, admin, faculty, student)
- Admin dashboard with 8 management modules
- Timetable lifecycle management (Draft → Published → Archived)
- AI-powered schedule upload and conflict detection via Groq LLaMA

## [0.1.0] - 2026-05-20
### Added
- Initial project scaffolding
- Basic GoRouter navigation with role-based guards
- Dark glassmorphic design system with Riverpod state management
