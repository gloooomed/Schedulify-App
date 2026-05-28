import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../config/config_store.dart';
import '../../../services/supabase_client.dart';
import '../../../shared/widgets/widgets.dart';
import '../widgets/overview_tab.dart';
import '../widgets/departments_tab.dart';
import '../widgets/courses_tab.dart';
import '../widgets/classrooms_tab.dart';
import '../widgets/users_tab.dart';
import '../widgets/timetables_tab.dart';
import '../widgets/upload_tab.dart';

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
    ('overview', Icons.dashboard_rounded, 'Overview'),
    ('departments', Icons.business_rounded, 'Departments'),
    ('courses', Icons.book_rounded, 'Courses'),
    ('faculty', Icons.people_rounded, 'Faculty'),
    ('students', Icons.school_rounded, 'Students'),
    ('classrooms', Icons.room_rounded, 'Classrooms'),
    ('timetables', Icons.calendar_month_rounded, 'Timetables'),
    ('upload', Icons.upload_file_rounded, 'Upload'),
  ];

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final config = ConfigStore.instance.get();

    final screenWidth = MediaQuery.of(context).size.width;
    final showSidebar = screenWidth >= 720;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(user, config),
      body: SafeArea(
        child: Row(
          children: [
            if (showSidebar) _buildSidebar(user, config),
            // Main content — centred with max-width on very wide screens
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
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (MediaQuery.of(context).size.width < 720)
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          Text(
            _navItems.firstWhere((n) => n.$1 == _section).$3,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const Spacer(),
          if (user != null) ...[
            RoleBadge(role: user.role),
            const SizedBox(width: 12),
            Text(user.fullName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: AppColors.textMuted, size: 20),
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
      width: 230,
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: _sidebarContent(user, config),
    );
  }

  Widget _buildDrawer(user, config) {
    return Drawer(
      backgroundColor: AppColors.bgCard,
      child: _sidebarContent(user, config),
    );
  }

  Widget _sidebarContent(user, config) {
    return SafeArea(
      child: Column(
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.schedule_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Schedulify', style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                if (config?.collegeName != null)
                  Text(config!.collegeName!, style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ]),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          // Nav items
          ..._navItems.map((item) {
            // Super admin only: hide admins tab if not super_admin (show upload for all admin)
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
          const Divider(),
          _NavItem(
            icon: Icons.logout_rounded,
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
      // ValueKey forces Flutter to create a FRESH element when switching
      // between Faculty and Students — avoids stale-data widget reuse.
      'faculty'     => const UsersTab(key: ValueKey('tab_faculty'), role: 'faculty'),
      'students'    => const UsersTab(key: ValueKey('tab_student'), role: 'student'),
      'classrooms'  => const ClassroomsTab(),
      'timetables'  => const TimetablesTab(),
      'upload'      => const UploadTab(),
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
    final c = color ?? (isActive ? AppColors.primary : AppColors.textSecondary);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(icon, color: c, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: c, fontWeight:
              isActive ? FontWeight.w600 : FontWeight.w400, fontSize: 14)),
        ]),
      ),
    );
  }
}
