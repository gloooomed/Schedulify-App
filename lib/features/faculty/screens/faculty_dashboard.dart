import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../config/config_store.dart';
import '../../../services/db_service.dart';
import '../../../services/supabase_client.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';

class FacultyDashboard extends ConsumerStatefulWidget {
  const FacultyDashboard({super.key});
  @override
  ConsumerState<FacultyDashboard> createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends ConsumerState<FacultyDashboard> {
  List<TimetableEntry> _schedule = [];
  bool _loading = true;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

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
      final data = await DbService.getFacultySchedule(user.id);
      if (mounted) setState(() { _schedule = data; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  List<TimetableEntry> _entriesForDay(DateTime day) {
    final weekday = day.weekday % 7; // Mon=1→1, Sun=0
    return _schedule.where((e) => e.dayOfWeek == weekday).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  List<TimetableEntry> get _todayEntries => _entriesForDay(DateTime.now());
  List<TimetableEntry> get _selectedEntries => _entriesForDay(_selectedDay);

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Faculty Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (user != null) Text(user.fullName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
        actions: [
          if (user != null) RoleBadge(role: user.role),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.logout_rounded, size: 20), onPressed: _logout),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: RefreshIndicator(
            onRefresh: _load, color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Today's classes
                GlassCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.today_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text("Today — ${DateFormat('EEEE, d MMM').format(DateTime.now())}",
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 15)),
                    ]),
                    const SizedBox(height: 16),
                    if (_loading)
                      ...List.generate(3, (_) => Padding(padding: const EdgeInsets.only(bottom: 8),
                          child: ShimmerBox(height: 56, radius: 10)))
                    else if (_todayEntries.isEmpty)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No classes today 🎉', style: TextStyle(color: AppColors.textSecondary)),
                      ))
                    else
                      ..._todayEntries.map((e) => _ClassSlot(entry: e)),
                  ]),
                ),
                const SizedBox(height: 20),

                // Weekly calendar
                GlassCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [
                      Icon(Icons.calendar_view_week_rounded, color: AppColors.info, size: 20),
                      SizedBox(width: 8),
                      Text('Weekly Schedule', style: TextStyle(fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary, fontSize: 15)),
                    ]),
                    const SizedBox(height: 12),
                    TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
                      calendarFormat: CalendarFormat.week,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      eventLoader: (day) => _entriesForDay(day).isNotEmpty ? [true] : [],
                      onDaySelected: (sel, foc) => setState(() {
                        _selectedDay = sel; _focusedDay = foc;
                      }),
                      calendarStyle: const CalendarStyle(
                        defaultTextStyle: TextStyle(color: AppColors.textPrimary),
                        weekendTextStyle: TextStyle(color: AppColors.textSecondary),
                        selectedDecoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        todayDecoration: BoxDecoration(color: AppColors.info, shape: BoxShape.circle),
                        markerDecoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                        outsideDaysVisible: false,
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                        leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.textSecondary),
                        rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.textSecondary),
                      ),
                      daysOfWeekStyle: const DaysOfWeekStyle(
                        weekdayStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        weekendStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_selectedEntries.isNotEmpty) ...[
                      Text(DateFormat('EEEE classes').format(_selectedDay),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 8),
                      ..._selectedEntries.map((e) => _ClassSlot(entry: e)),
                    ],
                  ]),
                ),
                const SizedBox(height: 20),

                // Weekly stats
                GlassCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('This Week', style: TextStyle(fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary, fontSize: 15)),
                    const SizedBox(height: 16),
                    Row(children: [
                      _MiniStat('Classes', '${_schedule.length}', Icons.class_rounded, AppColors.primary),
                      _MiniStat('Courses', '${_schedule.map((e) => e.courseId).toSet().length}',
                          Icons.book_rounded, AppColors.info),
                      _MiniStat('Labs', '${_schedule.where((e) => e.sessionType == 'lab').length}',
                          Icons.science_rounded, AppColors.warning),
                    ]),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassSlot extends StatelessWidget {
  final TimetableEntry entry;
  const _ClassSlot({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.sessionType) {
      'lab' => AppColors.warning,
      'tutorial' => AppColors.info,
      _ => AppColors.primary,
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
          Text(entry.course?.name ?? 'Unknown Course',
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14)),
          Text('${entry.startTime.substring(0, 5)} - ${entry.endTime.substring(0, 5)}'
              '${entry.classroom != null ? ' · ${entry.classroom!.name}' : ''}'
              '${entry.studentGroup != null ? ' · ${entry.studentGroup}' : ''}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
          child: Text(entry.sessionType.toUpperCase(),
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MiniStat(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
          color: AppColors.textPrimary)),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    ]),
  );
}
