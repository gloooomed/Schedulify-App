import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../services/db_service.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import 'attendance_tab.dart';
import 'assignments_tab.dart';

class StudentDashboard extends ConsumerStatefulWidget {
  const StudentDashboard({super.key});
  @override
  ConsumerState<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends ConsumerState<StudentDashboard> {
  List<TimetableEntry> _schedule = [];
  List<Course> _courses = [];
  bool _loading = true;
  bool _loadingCourses = false;
  bool _coursesLoaded = false;
  String? _error;
  String? _coursesError;
  String _section = 'schedule';
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _navItems = [
    ('schedule',     Icons.calendar_month_rounded, 'Schedule'),
    ('courses',      Icons.menu_book_rounded,      'Courses'),
    ('attendance',   Icons.fact_check_rounded,     'Attendance'),
    ('assignments',  Icons.assignment_rounded,     'Assignments'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSchedule());
  }

  Future<void> _loadSchedule({bool forceRefresh = false}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await DbService.getStudentSchedule(user.id, forceRefresh: forceRefresh);
      if (mounted) setState(() { _schedule = data; _loading = false; });
    } catch (e) {
      debugPrint('StudentDashboard schedule error: $e');
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _loadCourses({bool forceRefresh = false}) async {
    if (_loadingCourses) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() { _loadingCourses = true; _coursesError = null; });
    try {
      final data = await DbService.getStudentCourses(user.id);
      if (mounted) setState(() { _courses = data; _loadingCourses = false; _coursesLoaded = true; });
    } catch (e) {
      debugPrint('StudentDashboard courses error: $e');
      if (mounted) setState(() { _loadingCourses = false; _coursesError = e.toString(); });
    }
  }

  List<TimetableEntry> get _todayClasses {
    final weekday = DateTime.now().weekday % 7;
    return _schedule.where((e) => e.dayOfWeek == weekday).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user   = ref.watch(currentUserProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final screenWidth  = MediaQuery.of(context).size.width;
    final showSidebar  = screenWidth >= 720;

    return Scaffold(
      key: _scaffoldKey,
      drawer: showSidebar ? null : _buildDrawer(user),
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Row(
          children: [
            if (showSidebar) _buildSidebar(user),
            Expanded(
              child: Column(
                children: [
                  _buildTopBar(user, isDark, context, showSidebar),
                  Expanded(child: _buildContent(user)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(user, bool isDark, BuildContext context, bool showSidebar) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(bottom: BorderSide(color: context.borderColor)),
      ),
      child: Row(
        children: [
          if (!showSidebar)
            IconButton(
              icon: Icon(Icons.menu_rounded, color: context.textPrimary),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          Text(
            _navItems.firstWhere((n) => n.$1 == _section).$3,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.textPrimary),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                color: context.textSecondary, size: 20),
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

  Widget _buildSidebar(user) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(right: BorderSide(color: context.borderColor)),
      ),
      child: _sidebarContent(user),
    );
  }

  Widget _buildDrawer(user) => Drawer(backgroundColor: context.surfaceColor, child: _sidebarContent(user));

  Widget _sidebarContent(user) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(children: [
              SvgPicture.asset('assets/images/App_icon.svg', width: 36, height: 36),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Schedulify', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary)),
                Text('Student', style: TextStyle(fontSize: 11, color: context.textSecondary)),
              ]),
            ]),
          ),
          Divider(height: 1, color: context.borderColor),
          const SizedBox(height: 8),
          ..._navItems.map((item) {
            final isActive = _section == item.$1;
            return _NavItem(
              icon: item.$2, label: item.$3, isActive: isActive,
              onTap: () {
                final newSection = item.$1;
                setState(() => _section = newSection);
                // Lazy-load courses on first visit
                if (newSection == 'courses' && !_coursesLoaded && !_loadingCourses) {
                  _loadCourses();
                }
                if (MediaQuery.of(context).size.width < 720) Navigator.of(context).pop();
              },
            );
          }),
          const Spacer(),
          Divider(height: 1, color: context.borderColor),
          const SizedBox(height: 4),
          _NavItem(icon: Icons.logout_outlined, label: 'Logout', isActive: false,
              onTap: _logout, color: AppColors.danger),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildContent(user) {
    return switch (_section) {
      'attendance'  => const StudentAttendanceTab(),
      'assignments' => const StudentAssignmentsTab(),
      'courses'     => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: RefreshIndicator(onRefresh: () => _loadCourses(forceRefresh: true), color: AppColors.primary,
                child: _coursesView()),
          ),
        ),
      _ => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: RefreshIndicator(onRefresh: () => _loadSchedule(forceRefresh: true), color: AppColors.primary,
                child: _scheduleView(user)),
          ),
        ),
    };
  }

  Widget _scheduleView(Profile? user) {
    // Error state
    if (_error != null) {
      return ErrorView(
        message: 'Could not load your schedule. Check your connection.',
        onRetry: () => _loadSchedule(forceRefresh: true),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Profile card ──
        if (user != null)
          GlassCard(
            child: Row(children: [
              CircleAvatar(
                radius: 28, backgroundColor: AppColors.student.withOpacity(0.2),
                child: Text(
                  user.firstName.isNotEmpty
                      ? (user.lastName.isNotEmpty
                          ? '${user.firstName[0]}${user.lastName[0]}'
                          : user.firstName[0])
                      : '?',
                  style: TextStyle(color: AppColors.student, fontWeight: FontWeight.w700, fontSize: 18)),
              ),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user.fullName, style: TextStyle(fontWeight: FontWeight.w700,
                    fontSize: 16, color: context.textPrimary)),
                if (user.rollNumber != null)
                  Text(user.rollNumber!, style: TextStyle(color: context.textSecondary, fontSize: 13)),
                Row(children: [
                  if (user.batch != null) _Tag(user.batch!, AppColors.info),
                  if (user.semester != null) ...[
                    const SizedBox(width: 6),
                    _Tag(user.semester!, AppColors.faculty),
                  ],
                ]),
              ]),
            ]),
          ),
        const SizedBox(height: 20),
        // ── Stat row (skeleton or real) ──
        if (_loading)
          const SkeletonStatRow()
        else
          Row(children: [
            Expanded(child: StatCard(label: 'Weekly Classes', value: '${_schedule.length}',
                icon: Icons.class_rounded, color: AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: StatCard(label: 'Today', value: '${_todayClasses.length}',
                icon: Icons.today_rounded, color: AppColors.info)),
          ]),
        const SizedBox(height: 20),
        // ── Today's classes ──
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.today_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text("Today — ${DateFormat('EEEE, d MMM').format(DateTime.now())}",
                  style: TextStyle(fontWeight: FontWeight.w700, color: context.textPrimary)),
            ]),
            const SizedBox(height: 16),
            if (_loading)
              ...List.generate(3, (_) => Padding(padding: const EdgeInsets.only(bottom: 8),
                  child: ShimmerBox(height: 56, radius: 10)))
            else if (_todayClasses.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(16),
                  child: Text('No classes today 🎉', style: TextStyle(color: AppColors.textSecondary))))
            else
              ..._todayClasses.map((e) => _StudentSlot(entry: e)),
          ]),
        ),
        const SizedBox(height: 20),
        // ── Full week ──
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Full Week', style: TextStyle(fontWeight: FontWeight.w700,
                color: AppColors.textPrimary, fontSize: 15)),
            const SizedBox(height: 16),
            if (_loading)
              ...List.generate(3, (_) => const Padding(padding: EdgeInsets.only(bottom: 8),
                  child: SkeletonListTile()))
            else
              ...List.generate(6, (i) {
                final days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
                final entries = _schedule.where((e) => e.dayOfWeek == i + 1).toList()
                  ..sort((a, b) => a.startTime.compareTo(b.startTime));
                if (entries.isEmpty) return const SizedBox.shrink();
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(days[i], style: TextStyle(fontWeight: FontWeight.w600,
                        color: context.textSecondary, fontSize: 13)),
                  ),
                  ...entries.map((e) => _StudentSlot(entry: e)),
                ]);
              }),
          ]),
        ),
      ],
    );
  }

  Widget _coursesView() {
    if (_coursesError != null) {
      return ErrorView(
        message: 'Could not load your courses. Pull down to retry.',
        onRetry: () => _loadCourses(forceRefresh: true),
      );
    }
    if (_loadingCourses) {
      return ListView(padding: const EdgeInsets.all(16),
          children: List.generate(5, (_) => const Padding(padding: EdgeInsets.only(bottom: 10),
              child: SkeletonCard(height: 72))));
    }
    if (_courses.isEmpty) {
      return const Center(child: EmptyState(icon: Icons.menu_book_rounded,
          title: 'No enrolled courses', subtitle: 'Contact your administrator to get enrolled'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _courses.length,
      itemBuilder: (_, i) {
        final c = _courses[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(c.code, style: const TextStyle(color: AppColors.info,
                    fontWeight: FontWeight.w700, fontSize: 12)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.name, style: TextStyle(fontWeight: FontWeight.w600, color: context.textPrimary)),
                Text('${c.credits} Credits · ${c.courseType.toUpperCase()}',
                    style: TextStyle(fontSize: 12, color: context.textSecondary)),
                if (c.department != null)
                  Text(c.department!.name,
                      style: TextStyle(fontSize: 11, color: context.textMuted)),
              ])),
              if (c.isElective) _Tag('Elective', AppColors.warning),
            ]),
          ),
        );
      },
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

String _fmtTime(String? t) {
  if (t == null || t.isEmpty) return '--:--';
  return t.length >= 5 ? t.substring(0, 5) : t;
}

class _StudentSlot extends StatelessWidget {
  final TimetableEntry entry;
  const _StudentSlot({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.sessionType) {
      'lab' => AppColors.warning,
      'tutorial' => AppColors.info,
      _ => AppColors.student,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(entry.course?.name ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
          Text(
            '${_fmtTime(entry.startTime)} - ${_fmtTime(entry.endTime)}'
            '${entry.faculty != null ? ' · ${entry.faculty!.fullName}' : ''}'
            '${entry.classroom != null ? ' · ${entry.classroom!.name}' : ''}',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
            child: Text(entry.sessionType.toUpperCase(),
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 4),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(5)),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color? color;

  const _NavItem({required this.icon, required this.label,
      required this.isActive, required this.onTap, this.color});

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
          Text(label, style: TextStyle(color: c,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, fontSize: 14)),
        ]),
      ),
    );
  }
}
