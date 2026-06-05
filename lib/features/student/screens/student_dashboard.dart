import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../services/db_service.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import 'attendance_tab.dart';

class StudentDashboard extends ConsumerStatefulWidget {
  const StudentDashboard({super.key});
  @override
  ConsumerState<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends ConsumerState<StudentDashboard> {
  List<TimetableEntry> _schedule = [];
  List<Course> _courses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final r = await Future.wait([
        DbService.getStudentSchedule(user.id),
        DbService.getStudentCourses(user.id),
      ]);
      setState(() {
        _schedule = r[0] as List<TimetableEntry>;
        _courses = r[1] as List<Course>;
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
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
    final user = ref.watch(currentUserProvider);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Student Portal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            if (user != null) Text(user.fullName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
          actions: [
            if (user != null) RoleBadge(role: user.role),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.logout_rounded, size: 20), onPressed: _logout),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Schedule', icon: Icon(Icons.calendar_today_rounded, size: 16)),
              Tab(text: 'Courses',  icon: Icon(Icons.book_rounded, size: 16)),
              Tab(text: 'Attendance', icon: Icon(Icons.fact_check_rounded, size: 16)),
            ],
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primary,
            labelStyle: TextStyle(fontSize: 12),
          ),
        ),
        body: TabBarView(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: _scheduleView(user),
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: _coursesView(),
                ),
              ),
            ),
            const StudentAttendanceTab(),
          ],
        ),
      ),
    );
  }

  Widget _scheduleView(Profile? user) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
                  style: const TextStyle(color: AppColors.student,
                      fontWeight: FontWeight.w700, fontSize: 18)),
              ),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w700,
                    fontSize: 16, color: AppColors.textPrimary)),
                if (user.rollNumber != null)
                  Text(user.rollNumber!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                Row(children: [
                  if (user.batch != null)
                    _Tag(user.batch!, AppColors.info),
                  if (user.semester != null) ...[
                    const SizedBox(width: 6),
                    _Tag(user.semester!, AppColors.faculty),
                  ],
                ]),
              ]),
            ]),
          ),
        const SizedBox(height: 20),

        Row(children: [
          Expanded(child: StatCard(label: 'Total Classes', value: '${_schedule.length}',
              icon: Icons.class_rounded, color: AppColors.primary)),
          const SizedBox(width: 12),
          Expanded(child: StatCard(label: 'Enrolled Courses', value: '${_courses.length}',
              icon: Icons.book_rounded, color: AppColors.info)),
        ]),
        const SizedBox(height: 20),

        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.today_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text("Today — ${DateFormat('EEEE, d MMM').format(DateTime.now())}",
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ]),
            const SizedBox(height: 16),
            if (_loading)
              ...List.generate(3, (_) => Padding(padding: const EdgeInsets.only(bottom: 8),
                  child: ShimmerBox(height: 56, radius: 10)))
            else if (_todayClasses.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No classes today 🎉', style: TextStyle(color: AppColors.textSecondary)),
              ))
            else
              ..._todayClasses.map((e) => _StudentSlot(entry: e)),
          ]),
        ),
        const SizedBox(height: 20),

        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Full Week', style: TextStyle(fontWeight: FontWeight.w700,
                color: AppColors.textPrimary, fontSize: 15)),
            const SizedBox(height: 16),
            ...List.generate(6, (i) {
              final days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
              final entries = _schedule.where((e) => e.dayOfWeek == i + 1).toList()
                ..sort((a, b) => a.startTime.compareTo(b.startTime));
              if (entries.isEmpty) return const SizedBox.shrink();
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(days[i], style: const TextStyle(fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary, fontSize: 13)),
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
    if (_loading) {
      return ListView(padding: const EdgeInsets.all(16),
          children: List.generate(5, (_) => Padding(padding: const EdgeInsets.only(bottom: 10),
              child: ShimmerBox(height: 72, radius: 14))));
    }
    if (_courses.isEmpty) {
      return const Center(child: EmptyState(icon: Icons.book_rounded,
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
                Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
                Text('${c.credits} Credits · ${c.courseType.toUpperCase()}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                if (c.department != null)
                  Text(c.department!.name,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ])),
              if (c.isElective)
                _Tag('Elective', AppColors.warning),
            ]),
          ),
        );
      },
    );
  }
}

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
          Text(entry.course?.name ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600,
              color: AppColors.textPrimary, fontSize: 14)),
          Text(
            '${_fmtTime(entry.startTime)} - ${_fmtTime(entry.endTime)}'
            '${entry.faculty != null ? ' · ${entry.faculty!.fullName}' : ''}'
            '${entry.classroom != null ? ' · ${entry.classroom!.name}' : ''}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
