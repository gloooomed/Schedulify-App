import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../config/config_store.dart';
import '../../../shared/widgets/widgets.dart';
import '../widgets/overview_tab.dart';
import '../widgets/departments_tab.dart';
import '../widgets/courses_tab.dart';
import '../widgets/classrooms_tab.dart';
import '../widgets/users_tab.dart';
import '../widgets/timetables_tab.dart';
import '../widgets/upload_tab.dart';
import '../widgets/attendance_admin_tab.dart';
import '../widgets/geofence_tab.dart';
import '../widgets/assignments_admin_tab.dart';

class AdminShell extends ConsumerStatefulWidget {
  final String initialSection;
  const AdminShell({super.key, this.initialSection = 'overview'});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late String _section;
  bool _hasServiceKey = false;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
    _checkServiceKey();
  }

  Future<void> _checkServiceKey() async {
    final cfg = await ConfigStore.instance.getAsync();
    if (mounted) {
      setState(() {
        _hasServiceKey = cfg?.serviceRoleKey != null && cfg!.serviceRoleKey!.isNotEmpty;
      });
    }
  }

  static const _navItems = [
    ('overview',    Icons.space_dashboard_rounded,     'Overview'),
    ('departments', Icons.domain_rounded,              'Departments'),
    ('courses',     Icons.menu_book_rounded,           'Courses'),
    ('faculty',     Icons.co_present_rounded,          'Faculty'),
    ('students',    Icons.groups_rounded,              'Students'),
    ('classrooms',  Icons.meeting_room_rounded,        'Classrooms'),
    ('timetables',  Icons.calendar_month_rounded,      'Timetables'),
    ('upload',      Icons.auto_awesome_rounded,        'AI Upload'),
    ('attendance',  Icons.fact_check_rounded,          'Attendance'),
    ('geofence',    Icons.radar_rounded,               'Geofence'),
    ('assignments', Icons.assignment_rounded,          'Assignments'),
  ];

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user   = ref.watch(currentUserProvider);
    final config = ConfigStore.instance.get();
    final screenWidth = MediaQuery.of(context).size.width;
    final showSidebar = screenWidth >= 720;

    return Scaffold(
      key: _scaffoldKey,
      drawer: showSidebar ? null : _buildDrawer(user, config),
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Row(
          children: [
            if (showSidebar) _buildSidebar(user, config),
            Expanded(
              child: Column(
                children: [
                  _buildTopBar(user, config, context),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: _buildContent(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(user, config, BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final hasServiceKey = _hasServiceKey;
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(bottom: BorderSide(color: context.borderColor)),
      ),
      child: Row(
        children: [
          if (MediaQuery.of(context).size.width < 720)
            IconButton(
              icon: Icon(Icons.menu_rounded, color: context.textPrimary),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          Text(
            _navItems.firstWhere((n) => n.$1 == _section).$3,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: context.textPrimary),
          ),
          const Spacer(),
          // Service role key button
          Tooltip(
            message: hasServiceKey
                ? 'Service role key is set ✓'
                : 'Set service role key (required for user management)',
            child: IconButton(
              icon: Stack(
                children: [
                  Icon(Icons.key_rounded,
                      color: hasServiceKey ? AppColors.success : AppColors.warning, size: 20),
                  if (!hasServiceKey)
                    Positioned(
                      right: 0, top: 0,
                      child: Container(
                        width: 7, height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.warning, shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
              onPressed: () => _showServiceKeySheet(context),
            ),
          ),
          // Theme toggle
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: context.textSecondary, size: 20,
            ),
            tooltip: isDark ? 'Light mode' : 'Dark mode',
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          const SizedBox(width: 12),
          if (user != null) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RoleBadge(role: user.role),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(user.fullName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showServiceKeySheet(BuildContext context) async {
    final config = await ConfigStore.instance.getAsync();
    final ctrl = TextEditingController(text: config?.serviceRoleKey ?? '');
    if (!context.mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 20, right: 20, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.key_rounded, color: AppColors.warning, size: 22),
              const SizedBox(width: 10),
              Text('Service Role Key',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                      color: context.textPrimary)),
            ]),
            const SizedBox(height: 8),
            Text(
              'Required for creating and deleting users. Find it in:\n'
              'Supabase Dashboard → Settings → API → service_role',
              style: TextStyle(fontSize: 13, color: context.textSecondary),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: ctrl,
              label: 'service_role key',
              obscureText: true,
              prefixIcon: Icons.vpn_key_outlined,
              hint: 'eyJhbGciOiJIUzI1NiIsInR5c...',
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Save Key',
              width: double.infinity,
              onPressed: () async {
                final current = await ConfigStore.instance.getAsync();
                if (current == null) return;
                await ConfigStore.instance.set(AppConfig(
                  supabaseUrl:     current.supabaseUrl,
                  supabaseAnonKey: current.supabaseAnonKey,
                  collegeName:     current.collegeName,
                  collegeId:       current.collegeId,
                  setupComplete:   current.setupComplete,
                  serviceRoleKey:  ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
                ));
                if (ctx.mounted) Navigator.pop(ctx);
                _checkServiceKey();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Service role key saved.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(user, config) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(right: BorderSide(color: context.borderColor)),
      ),
      child: _sidebarContent(user, config),
    );
  }

  Widget _buildDrawer(user, config) {
    return Drawer(backgroundColor: context.surfaceColor, child: _sidebarContent(user, config));
  }

  Widget _sidebarContent(user, config) {
    return SafeArea(
      child: Column(
        children: [
          // Logo area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(children: [
              SvgPicture.asset('assets/images/App_icon.svg', width: 36, height: 36),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Schedulify',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        color: context.textPrimary)),
                if (config?.collegeName != null)
                  Text(config!.collegeName!,
                      style: TextStyle(fontSize: 11, color: context.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ]),
          ),
          Divider(height: 1, color: context.borderColor),
          const SizedBox(height: 8),
          // Nav items
          ..._navItems.map((item) {
            final isActive = _section == item.$1;
            return _NavItem(
              icon: item.$2,
              label: item.$3,
              isActive: isActive,
              onTap: () {
                setState(() => _section = item.$1);
                if (MediaQuery.of(context).size.width < 720) {
                  Navigator.of(context).pop();
                }
              },
            );
          }),
          const Spacer(),
          Divider(height: 1, color: context.borderColor),
          const SizedBox(height: 4),
          _NavItem(
            icon: Icons.logout_outlined,
            label: 'Logout',
            isActive: false,
            onTap: _logout,
            color: AppColors.danger,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return switch (_section) {
      'overview'    => const OverviewTab(),
      'departments' => const DepartmentsTab(),
      'courses'     => const CoursesTab(),
      'faculty'     => const UsersTab(key: ValueKey('tab_faculty'), role: 'faculty'),
      'students'    => const UsersTab(key: ValueKey('tab_student'), role: 'student'),
      'classrooms'  => const ClassroomsTab(),
      'timetables'  => const TimetablesTab(),
      'upload'      => const UploadTab(),
      'attendance'  => const AttendanceAdminTab(),
      'geofence'    => const GeofenceTab(),
      'assignments' => const AssignmentsAdminTab(),
      _             => const OverviewTab(),
    };
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color? color;

  const _NavItem({
    required this.icon, required this.label,
    required this.isActive, required this.onTap, this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? (isActive ? AppColors.primary : context.textSecondary);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(icon, color: c, size: 19),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(
              color: c,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              fontSize: 14)),
        ]),
      ),
    );
  }
}
