<h1 align="center">Schedulify</h1>

<p align="center">
  AI-powered college timetable management. Multi-tenant, conflict-free, and built for scale.
</p>

<p align="center">
  <a href="https://github.com/gloooomed/Schedulify-App/issues/new?labels=bug">Report Bug</a>
  ·
  <a href="https://github.com/gloooomed/Schedulify-App/issues/new?labels=enhancement">Request Feature</a>
</p>

<p align="center">
  <a href="https://github.com/gloooomed/Schedulify-App/forks">
    <img src="https://img.shields.io/github/forks/gloooomed/Schedulify-App?style=for-the-badge&labelColor=0A0F1E&color=3B82F6&label=FORKS" alt="Forks" />
  <a href="#">
    <img src="https://img.shields.io/badge/PLATFORM-Android-8B5CF6?style=for-the-badge&labelColor=0A0F1E" alt="Platform" />
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

- **Multi-Tenant Architecture** - Each college gets its own isolated Supabase project. One app, many institutions, zero data bleed.
- **AI Schedule Parsing** - Upload a CSV or paste raw text. Groq's LLaMA model parses it, detects conflicts, and saves structured timetable entries.
- **Role-Based Dashboards** - Admins manage everything. Faculty see their classes. Students see their schedule. Each role gets exactly what they need.
- **Setup Wizard** - New colleges onboard themselves in 5 steps. No backend intervention required.
- **Live Conflict Detection** - The AI flags scheduling conflicts before entries are saved, preventing double-bookings automatically.

---

## Tech Stack

| Category | Technology |
|---|---|
| Framework | [![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev) [![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev) |
| State Management | [![Riverpod](https://img.shields.io/badge/Riverpod-00BCD4?style=for-the-badge&logo=dart&logoColor=white)](https://riverpod.dev) |
| Navigation | [![GoRouter](https://img.shields.io/badge/GoRouter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://pub.dev/packages/go_router) |
| Backend | [![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com) |
| AI | [![Groq](https://img.shields.io/badge/Groq_LLaMA-F55036?style=for-the-badge&logo=groq&logoColor=white)](https://groq.com) |
| Animations | [![Flutter Animate](https://img.shields.io/badge/Flutter_Animate-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://pub.dev/packages/flutter_animate) |

---

## Getting Started

```bash
git clone https://github.com/gloooomed/Schedulify-App.git
cd Schedulify-App
flutter pub get
```

Create a `dart_defines.json` file in the project root:

```json
{
  "VENDOR_SUPABASE_URL": "https://your-vendor-project.supabase.co",
  "VENDOR_SUPABASE_ANON_KEY": "your_vendor_anon_key",
  "VENDOR_ACCESS_CODE": "your_access_code",
  "GROQ_API_KEY": "your_groq_key"
}
```

```bash
flutter run --dart-define-from-file=dart_defines.json
```

---

## Project Structure

```
Schedulify-App/
├── lib/
│   ├── main.dart                          # App entry + Supabase + Riverpod init
│   ├── config/
│   │   └── config_store.dart              # SharedPreferences college config
│   ├── core/
│   │   ├── theme/app_theme.dart           # Dark glassmorphic design system
│   │   ├── providers/auth_provider.dart   # Riverpod auth state notifier
│   │   └── router/app_router.dart         # GoRouter with role-based guards
│   ├── models/models.dart                 # All domain models
│   ├── services/
│   │   ├── supabase_client.dart           # Dynamic multi-tenant Supabase proxy
│   │   ├── vendor_registry.dart           # Central college registry service
│   │   ├── groq_service.dart              # AI schedule parsing via Groq
│   │   ├── db_service.dart                # Full CRUD database layer
│   │   └── student_service.dart           # Student enrollment helpers
│   ├── shared/widgets/widgets.dart        # GlassCard, StatCard, PrimaryButton, etc.
│   └── features/
│       ├── gateway/                       # College ID entry screen
│       ├── auth/                          # Login screen
│       ├── setup/                         # 5-step onboarding wizard
│       ├── admin/                         # Admin shell + 8 module tabs
│       ├── faculty/                       # Faculty dashboard + TableCalendar
│       └── student/                       # Student schedule + courses view
├── android/                               # Android build configuration
├── assets/images/                         # App logo and static assets
├── .env.example                           # Environment variable template
└── dart_defines.json                      # ← gitignored, never commit this
```

---

## Contributing

### Prerequisites

| Requirement | Version | Notes |
|---|---|---|
| [Flutter](https://flutter.dev/docs/get-started/install) | 3.32+ | Stable channel |
| [Android Studio](https://developer.android.com/studio) | Latest | For emulator + SDK |
| [Groq API Key](https://console.groq.com/keys) | - | Free tier works |
| [Supabase Account](https://supabase.com) | - | Free plan sufficient |

### Steps

1. **Fork** the repository
2. **Create a branch** for your feature:
   ```bash
   git checkout -b feat/your-feature-name
   ```
3. **Commit** with a clear message:
   ```bash
   git commit -m "feat: describe your change"
   ```
4. **Push** and open a Pull Request against `main`

### Guidelines
- One feature or fix per PR
- Follow existing Dart/Flutter conventions
- For larger changes, open an issue first

---

<p align="center">
  <em>Built for colleges. Runs everywhere Android does.</em>
</p>

<!-- v1.0.0 -->
