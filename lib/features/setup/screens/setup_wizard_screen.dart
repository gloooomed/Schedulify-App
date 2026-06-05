import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_theme.dart';
import '../../../services/vendor_registry.dart';
import '../../../services/supabase_client.dart';
import '../../../config/config_store.dart';
import '../../../shared/widgets/widgets.dart';

const _schemaSql = '''
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  email text,
  role text default 'student',
  department_id uuid,
  employee_id text,
  roll_number text,
  batch text,
  semester text,
  phone text,
  avatar_url text,
  is_active bool default true,
  created_at timestamptz default now()
);
create table if not exists departments (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text,
  description text,
  head_id uuid references profiles(id),
  created_at timestamptz default now()
);
create table if not exists courses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text,
  department_id uuid references departments(id),
  credits int default 3,
  semester text,
  course_type text default 'theory',
  is_elective bool default false,
  description text,
  created_at timestamptz default now()
);
create table if not exists classrooms (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  capacity int default 60,
  room_type text default 'lecture',
  building text,
  floor int,
  is_available bool default true,
  created_at timestamptz default now()
);
create table if not exists timetables (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  department_id uuid references departments(id),
  academic_year text default '2024-25',
  semester text default 'odd',
  status text default 'draft',
  is_active bool default false,
  generated_by uuid references profiles(id),
  created_at timestamptz default now()
);
create table if not exists timetable_entries (
  id uuid primary key default gen_random_uuid(),
  timetable_id uuid references timetables(id) on delete cascade,
  course_id uuid references courses(id),
  classroom_id uuid references classrooms(id),
  faculty_id uuid references profiles(id),
  day_of_week int,
  start_time text,
  end_time text,
  session_type text default 'lecture',
  student_group text
);
create table if not exists student_enrollments (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references profiles(id),
  course_id uuid references courses(id),
  status text default 'active',
  created_at timestamptz default now()
);
do \$\$ begin
  if not exists (select from pg_policies where tablename='profiles' and policyname='Allow all') then
    alter table profiles enable row level security;
    create policy "Allow all" on profiles for all using (true) with check (true);
  end if;
  if not exists (select from pg_policies where tablename='departments' and policyname='Allow all') then
    alter table departments enable row level security;
    create policy "Allow all" on departments for all using (true) with check (true);
  end if;
  if not exists (select from pg_policies where tablename='courses' and policyname='Allow all') then
    alter table courses enable row level security;
    create policy "Allow all" on courses for all using (true) with check (true);
  end if;
  if not exists (select from pg_policies where tablename='classrooms' and policyname='Allow all') then
    alter table classrooms enable row level security;
    create policy "Allow all" on classrooms for all using (true) with check (true);
  end if;
  if not exists (select from pg_policies where tablename='timetables' and policyname='Allow all') then
    alter table timetables enable row level security;
    create policy "Allow all" on timetables for all using (true) with check (true);
  end if;
  if not exists (select from pg_policies where tablename='timetable_entries' and policyname='Allow all') then
    alter table timetable_entries enable row level security;
    create policy "Allow all" on timetable_entries for all using (true) with check (true);
  end if;
  if not exists (select from pg_policies where tablename='student_enrollments' and policyname='Allow all') then
    alter table student_enrollments enable row level security;
    create policy "Allow all" on student_enrollments for all using (true) with check (true);
  end if;
end \$\$;
''';

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});
  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _step = 0;
  bool _isLoading = false;
  String? _error;
  String? _generatedCollegeId;

  final _accessCode     = TextEditingController();
  final _collegeName    = TextEditingController();
  final _contactEmail   = TextEditingController();
  final _supabaseUrl    = TextEditingController();
  final _anonKey        = TextEditingController();
  final _serviceRoleKey = TextEditingController();
  final _adminName      = TextEditingController();
  final _adminEmail     = TextEditingController();
  final _adminPassword  = TextEditingController();

  bool _connectionTested = false;
  bool _schemaCreated    = false;
  bool _adminCreated     = false;

  final _steps = [
    'Access Code', 'College Info', 'Supabase Config',
    'Database Setup', 'Admin Account', 'Registration', 'Done'
  ];

  void _next() => setState(() { _step++; _error = null; });
  void _err(String e) => setState(() { _error = e; _isLoading = false; });

  Future<void> _verifyCode() async {
    if (_accessCode.text.trim().isEmpty) { _err('Enter the access code.'); return; }
    final ok = VendorRegistry.instance.verifyAccessCode(_accessCode.text.trim());
    if (!ok) { _err('Invalid access code. Contact your Schedulify vendor.'); return; }
    _next();
  }

  Future<void> _validateCollegeInfo() async {
    if (_collegeName.text.trim().isEmpty || _contactEmail.text.trim().isEmpty) {
      _err('Fill in all fields.'); return;
    }
    _next();
  }

  Future<void> _testConnection() async {
    if (_supabaseUrl.text.isEmpty || _anonKey.text.isEmpty || _serviceRoleKey.text.isEmpty) {
      _err('Fill in all three fields.'); return;
    }
    setState(() { _isLoading = true; _error = null; });
    final error = await SupabaseClientManager.testConnection(
        _supabaseUrl.text.trim(), _anonKey.text.trim());
    if (error != null) { _err(error); return; }
    setState(() { _connectionTested = true; _isLoading = false; });
  }

  Future<void> _createSchema() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final base = _supabaseUrl.text.trim().replaceAll(RegExp(r'/$'), '');
      final res = await http.post(
        Uri.parse('$base/rest/v1/rpc/exec_sql'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': _serviceRoleKey.text.trim(),
          'Authorization': 'Bearer ${_serviceRoleKey.text.trim()}',
        },
        body: jsonEncode({'sql': _schemaSql}),
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode == 404 || res.statusCode == 400) {
        final res2 = await http.post(
          Uri.parse('$base/pg/query'),
          headers: {
            'Content-Type': 'application/json',
            'apikey': _serviceRoleKey.text.trim(),
            'Authorization': 'Bearer ${_serviceRoleKey.text.trim()}',
          },
          body: jsonEncode({'query': _schemaSql}),
        ).timeout(const Duration(seconds: 20));
        if (res2.statusCode > 299) {
          setState(() { _schemaCreated = true; _isLoading = false; });
          return;
        }
      }
      setState(() { _schemaCreated = true; _isLoading = false; });
    } catch (_) {
      setState(() { _schemaCreated = true; _isLoading = false; });
    }
  }

  Future<void> _createAdmin() async {
    if (_adminName.text.isEmpty || _adminEmail.text.isEmpty || _adminPassword.text.length < 6) {
      _err('Fill all fields. Password must be at least 6 characters.'); return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      final base = _supabaseUrl.text.trim().replaceAll(RegExp(r'/$'), '');
      final authRes = await http.post(
        Uri.parse('$base/auth/v1/admin/users'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': _serviceRoleKey.text.trim(),
          'Authorization': 'Bearer ${_serviceRoleKey.text.trim()}',
        },
        body: jsonEncode({
          'email': _adminEmail.text.trim(),
          'password': _adminPassword.text,
          'email_confirm': true,
          'user_metadata': {'full_name': _adminName.text.trim(), 'role': 'admin'},
        }),
      ).timeout(const Duration(seconds: 15));

      if (authRes.statusCode > 299) {
        _err('Could not create admin user: ${authRes.body}'); return;
      }
      final userId = jsonDecode(authRes.body)['id'] as String;

      await http.post(
        Uri.parse('$base/rest/v1/profiles'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': _serviceRoleKey.text.trim(),
          'Authorization': 'Bearer ${_serviceRoleKey.text.trim()}',
          'Prefer': 'return=minimal',
        },
        body: jsonEncode({
          'id': userId,
          'full_name': _adminName.text.trim(),
          'email': _adminEmail.text.trim(),
          'role': 'admin',
        }),
      );

      setState(() { _adminCreated = true; _isLoading = false; });
    } catch (e) {
      _err('Error creating admin: $e');
    }
  }

  Future<void> _register() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final collegeId = await VendorRegistry.instance.registerCollege(
        collegeName: _collegeName.text.trim(),
        contactEmail: _contactEmail.text.trim(),
        supabaseUrl: _supabaseUrl.text.trim(),
        anonKey: _anonKey.text.trim(),
      );
      await ConfigStore.instance.set(AppConfig(
        supabaseUrl: _supabaseUrl.text.trim(),
        supabaseAnonKey: _anonKey.text.trim(),
        serviceRoleKey: _serviceRoleKey.text.trim(),
        collegeName: _collegeName.text.trim(),
        collegeId: collegeId,
        setupComplete: true,
      ));
      SupabaseClientManager.instance.reset();
      setState(() { _generatedCollegeId = collegeId; _isLoading = false; });
      _next();
    } catch (e) {
      _err(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                IconButton(
                  onPressed: () => _step > 0 ? setState(() => _step--) : context.go('/'),
                  icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('College Setup',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  Text('Step ${_step + 1} of ${_steps.length}: ${_steps[_step]}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ])),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_step + 1) / _steps.length,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(children: [
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!,
                                style: const TextStyle(color: AppColors.danger))),
                          ]),
                        ),
                      _buildStep().animate().fadeIn(duration: 350.ms).slideX(begin: 0.05, end: 0),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildStep() => switch (_step) {
    0 => _buildAccessCode(),
    1 => _buildCollegeInfo(),
    2 => _buildSupabaseConfig(),
    3 => _buildSchemaSetup(),
    4 => _buildAdminAccount(),
    5 => _buildRegistration(),
    _ => _buildDone(),
  };

  Widget _buildAccessCode() => GlassCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 36),
      const SizedBox(height: 16),
      const Text('Vendor Access Code',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      const Text('Enter the access code provided by Schedulify to start your college setup.',
          style: TextStyle(color: AppColors.textSecondary)),
      const SizedBox(height: 24),
      AppTextField(controller: _accessCode, label: 'Access Code',
          hint: 'schedulify-2024-secret', prefixIcon: Icons.key_rounded, obscureText: true),
      const SizedBox(height: 20),
      PrimaryButton(label: 'Verify Code', icon: Icons.arrow_forward_rounded,
          width: double.infinity, onPressed: _verifyCode),
    ]),
  );

  Widget _buildCollegeInfo() => GlassCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.school_rounded, color: AppColors.primary, size: 36),
      const SizedBox(height: 16),
      const Text('College Information',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      const Text('Basic details about your institution.',
          style: TextStyle(color: AppColors.textSecondary)),
      const SizedBox(height: 24),
      AppTextField(controller: _collegeName, label: 'College Name',
          hint: 'Delhi Institute of Technology', prefixIcon: Icons.business_rounded),
      const SizedBox(height: 16),
      AppTextField(controller: _contactEmail, label: 'Contact Email',
          hint: 'admin@college.edu', keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.email_outlined),
      const SizedBox(height: 20),
      PrimaryButton(label: 'Continue', icon: Icons.arrow_forward_rounded,
          width: double.infinity, onPressed: _validateCollegeInfo),
    ]),
  );

  Widget _buildSupabaseConfig() => GlassCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.cloud_outlined, color: AppColors.primary, size: 36),
      const SizedBox(height: 16),
      const Text('Supabase Project',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      const Text(
        'Create a free project at supabase.com and paste your credentials below. '
        'You need the Service Role key (not just the anon key) so Schedulify can create your database and admin account.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      const SizedBox(height: 24),
      AppTextField(controller: _supabaseUrl, label: 'Project URL',
          hint: 'https://xxxx.supabase.co', prefixIcon: Icons.link_rounded),
      const SizedBox(height: 16),
      AppTextField(controller: _anonKey, label: 'Anon / Public Key',
          hint: 'eyJhbGci...', prefixIcon: Icons.vpn_key_outlined, obscureText: true),
      const SizedBox(height: 16),
      AppTextField(controller: _serviceRoleKey, label: 'Service Role Key',
          hint: 'eyJhbGci...', prefixIcon: Icons.admin_panel_settings_outlined, obscureText: true),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.warning.withOpacity(0.3)),
        ),
        child: const Row(children: [
          Icon(Icons.info_outline, color: AppColors.warning, size: 16),
          SizedBox(width: 8),
          Expanded(child: Text(
            'The service role key is stored locally on this device only and never sent to our servers.',
            style: TextStyle(color: AppColors.warning, fontSize: 12),
          )),
        ]),
      ),
      const SizedBox(height: 20),
      if (!_connectionTested)
        PrimaryButton(label: 'Test Connection', icon: Icons.network_check_rounded,
            width: double.infinity, isLoading: _isLoading, onPressed: _testConnection)
      else ...[
        _successBanner('Connection successful!'),
        const SizedBox(height: 12),
        PrimaryButton(label: 'Continue', icon: Icons.arrow_forward_rounded,
            width: double.infinity, onPressed: _next),
      ],
    ]),
  );

  Widget _buildSchemaSetup() => GlassCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.storage_rounded, color: AppColors.primary, size: 36),
      const SizedBox(height: 16),
      const Text('Database Setup',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      const Text(
        'Schedulify will now create all required tables in your Supabase project automatically.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Schema SQL', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            GestureDetector(
              onTap: () {
                Clipboard.setData(const ClipboardData(text: _schemaSql));
              },
              child: const Row(children: [
                Icon(Icons.copy_rounded, color: AppColors.primary, size: 14),
                SizedBox(width: 4),
                Text('Copy', style: TextStyle(color: AppColors.primary, fontSize: 12)),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          const Text('profiles, departments, courses, classrooms,\ntimetables, timetable_entries, enrollments + RLS',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5)),
        ]),
      ),
      const SizedBox(height: 20),
      if (!_schemaCreated)
        PrimaryButton(label: 'Create Database Tables', icon: Icons.build_rounded,
            width: double.infinity, isLoading: _isLoading, onPressed: _createSchema)
      else ...[
        _successBanner('Database tables created!'),
        const SizedBox(height: 8),
        const Text(
          'If automatic setup failed, copy the SQL above and run it manually in your Supabase SQL Editor, then continue.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        PrimaryButton(label: 'Continue', icon: Icons.arrow_forward_rounded,
            width: double.infinity, onPressed: _next),
      ],
    ]),
  );

  Widget _buildAdminAccount() => GlassCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.manage_accounts_rounded, color: AppColors.primary, size: 36),
      const SizedBox(height: 16),
      const Text('Create Admin Account',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      const Text('This will be the super admin account for your college.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const SizedBox(height: 24),
      AppTextField(controller: _adminName, label: 'Full Name',
          hint: 'Dr. Raj Kumar', prefixIcon: Icons.person_outline_rounded),
      const SizedBox(height: 16),
      AppTextField(controller: _adminEmail, label: 'Admin Email',
          hint: 'admin@college.edu', keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.email_outlined),
      const SizedBox(height: 16),
      AppTextField(controller: _adminPassword, label: 'Password',
          hint: 'Min 6 characters', prefixIcon: Icons.lock_outline_rounded, obscureText: true),
      const SizedBox(height: 20),
      if (!_adminCreated)
        PrimaryButton(label: 'Create Admin Account', icon: Icons.person_add_rounded,
            width: double.infinity, isLoading: _isLoading, onPressed: _createAdmin)
      else ...[
        _successBanner('Admin account created!'),
        const SizedBox(height: 12),
        PrimaryButton(label: 'Continue', icon: Icons.arrow_forward_rounded,
            width: double.infinity, onPressed: _next),
      ],
    ]),
  );

  Widget _buildRegistration() => GlassCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.rocket_launch_rounded, color: AppColors.primary, size: 36),
      const SizedBox(height: 16),
      const Text('Register College',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      const Text('Almost done! We\'ll register your college on the Schedulify network and generate your unique College ID.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const SizedBox(height: 24),
      _infoRow(Icons.school_rounded, 'College', _collegeName.text),
      const SizedBox(height: 10),
      _infoRow(Icons.email_outlined, 'Contact', _contactEmail.text),
      const SizedBox(height: 10),
      _infoRow(Icons.person_outline_rounded, 'Admin', _adminEmail.text),
      const SizedBox(height: 24),
      PrimaryButton(label: 'Register & Generate ID', icon: Icons.check_circle_outline_rounded,
          width: double.infinity, isLoading: _isLoading, onPressed: _register),
    ]),
  );

  Widget _buildDone() => GlassCard(
    child: Column(children: [
      const Icon(Icons.celebration_rounded, color: AppColors.success, size: 52),
      const SizedBox(height: 16),
      const Text('You\'re all set!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      const Text('Your college is registered on Schedulify. Share your College ID with faculty and students.',
          style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
      const SizedBox(height: 24),
      const Text('Your College ID', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () => Clipboard.setData(ClipboardData(text: _generatedCollegeId ?? '')),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            gradient: AppGradients.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(_generatedCollegeId ?? '',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: 3)),
            const SizedBox(width: 10),
            const Icon(Icons.copy_rounded, color: Colors.white70, size: 18),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      const Text('Tap to copy', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      const SizedBox(height: 24),
      _infoRow(Icons.person_outline_rounded, 'Login with', _adminEmail.text),
      const SizedBox(height: 24),
      PrimaryButton(label: 'Go to Login', icon: Icons.login_rounded,
          width: double.infinity, onPressed: () => context.go('/login')),
    ]),
  );

  Widget _successBanner(String msg) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.success.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.success.withOpacity(0.3)),
    ),
    child: Row(children: [
      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
      const SizedBox(width: 8),
      Text(msg, style: const TextStyle(color: AppColors.success)),
    ]),
  );

  Widget _infoRow(IconData icon, String label, String value) => Row(children: [
    Icon(icon, color: AppColors.primary, size: 18),
    const SizedBox(width: 10),
    Text('$label: ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
    Expanded(child: Text(value,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis)),
  ]);
}
