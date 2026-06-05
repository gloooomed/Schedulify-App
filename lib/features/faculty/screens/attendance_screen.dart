import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/attendance_models.dart';
import '../../../models/models.dart';
import '../../../services/attendance_service.dart';
import '../../../services/db_service.dart';
import '../../../shared/widgets/widgets.dart';
import 'qr_projection_screen.dart';

class FacultyAttendanceScreen extends ConsumerStatefulWidget {
  const FacultyAttendanceScreen({super.key});

  @override
  ConsumerState<FacultyAttendanceScreen> createState() =>
      _FacultyAttendanceScreenState();
}

class _FacultyAttendanceScreenState
    extends ConsumerState<FacultyAttendanceScreen> {
  List<TimetableEntry> _todayEntries = [];
  List<AttendanceSession> _todaySessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _loading = true);
    final weekday = DateTime.now().weekday % 7;
    final entries = await DbService.getFacultySchedule(user.id);
    final todayEntries = entries
        .where((e) => e.dayOfWeek == weekday)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final sessions = await AttendanceService.getFacultyTodaySessions(user.id);

    if (mounted) {
      setState(() {
        _todayEntries = todayEntries;
        _todaySessions = sessions;
        _loading = false;
      });
    }
  }

  Future<void> _startSession(TimetableEntry entry) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final existing = _todaySessions
        .where((s) => s.timetableEntryId == entry.id && s.isActive)
        .firstOrNull;

    if (existing != null) {
      ref.read(activeSessionProvider.notifier).restore(existing);
    } else {
      await ref.read(activeSessionProvider.notifier).start(
            timetableEntryId: entry.id,
            facultyId: user.id,
            departmentId: user.departmentId,
            courseId: entry.courseId,
          );
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const QrProjectionScreen(),
        fullscreenDialog: true,
      ),
    );
    await Future.delayed(const Duration(milliseconds: 300));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(3,
            (_) => Padding(padding: const EdgeInsets.only(bottom: 12),
                child: ShimmerBox(height: 100, radius: 14))),
      );
    }

    if (_todayEntries.isEmpty) {
      return const EmptyState(
        icon: Icons.event_busy_rounded,
        title: 'No classes today',
        subtitle: 'Your scheduled classes for today will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _todayEntries.length,
        itemBuilder: (_, i) {
          final entry = _todayEntries[i];
          final session = _todaySessions
              .where((s) => s.timetableEntryId == entry.id)
              .firstOrNull;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(entry.course?.name ?? 'Unknown Course',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary, fontSize: 15)),
                      Text(
                        '${_fmt(entry.startTime)} – ${_fmt(entry.endTime)}'
                        '${entry.classroom != null ? ' · ${entry.classroom!.name}' : ''}',
                        style: const TextStyle(fontSize: 13,
                            color: AppColors.textSecondary),
                      ),
                      Text(
                        entry.sessionType.toUpperCase(),
                        style: const TextStyle(fontSize: 11,
                            color: AppColors.textMuted),
                      ),
                    ]),
                  ),
                  _SessionStatusBadge(session),
                ]),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: session != null && session.status == 'ended'
                      ? OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Session Ended'),
                        )
                      : session != null && session.isActive
                          ? ElevatedButton.icon(
                              onPressed: () => _startSession(entry),
                              icon: const Icon(Icons.qr_code_rounded, size: 16),
                              label: const Text('View QR (Resume)'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success),
                            )
                          : ElevatedButton.icon(
                              onPressed: () => _startSession(entry),
                              icon: const Icon(Icons.play_arrow_rounded, size: 16),
                              label: const Text('Start Attendance Session'),
                            ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _SessionStatusBadge extends StatelessWidget {
  final AttendanceSession? session;
  const _SessionStatusBadge(this.session);

  @override
  Widget build(BuildContext context) {
    if (session == null) {
      return const SizedBox.shrink();
    }
    final (color, label) = switch (session!.status) {
      'active'    => (AppColors.success, 'LIVE'),
      'ended'     => (AppColors.textMuted, 'ENDED'),
      'cancelled' => (AppColors.danger, 'CANCELLED'),
      _           => (AppColors.textMuted, session!.status.toUpperCase()),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (session!.isActive) ...[
          Container(width: 7, height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
        ],
        Text(label, style: TextStyle(fontSize: 11,
            fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

String _fmt(String t) => t.length >= 5 ? t.substring(0, 5) : t;
