import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

class AdminShell extends ConsumerStatefulWidget {
  final String initialSection;
  const AdminShell({super.key, this.initialSection = 'overview'});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  late String _section;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
  }

  static const _navItems = [
    ('overview',    Icons.grid_view_rounded,          'Overview'),
    ('departments', Icons.business_outlined,           'Departments'),
    ('courses',     Icons.menu_book_outlined,          'Courses'),
    ('faculty',     Icons.person_outline_rounded,      'Faculty'),
    ('students',    Icons.school_outlined,             'Students'),
    ('classrooms',  Icons.meeting_room_outlined,       'Classrooms'),
    ('timetables',  Icons.calendar_month_outlined,     'Timetables'),
    ('upload',      Icons.upload_outlined,             'AI Upload'),
    ('attendance',  Icons.checklist_outlined,          'Attendance'),
    ('geofence',    Icons.location_on_outlined,        'Geofence'),
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
          // Theme toggle
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: context.textSecondary, size: 20,
            ),
            tooltip: isDark ? 'Light mode' : 'Dark mode',
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          const SizedBox(width: 4),
          if (user != null) ...[
            RoleBadge(role: user.role),
            const SizedBox(width: 10),
            Text(user.fullName,
                style: TextStyle(color: context.textSecondary, fontSize: 13)),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.logout_rounded, color: context.textMuted, size: 20),
              onPressed: _logout,
              tooltip: 'Logout',
            ),
          ],
        ],
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
    return Drawer(child: _sidebarContent(user, config));
  }

  Widget _sidebarContent(user, config) {
    return SafeArea(
      child: Column(
        children: [
          // Logo area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_month_rounded,
                    color: Colors.white, size: 20),
              ),
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
