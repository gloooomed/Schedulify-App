import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/widgets.dart';
import 'scanner_screen.dart';

class StudentAttendanceTab extends ConsumerWidget {
  const StudentAttendanceTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final historyAsync = ref.watch(studentAttendanceProvider(user.id));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(studentAttendanceProvider(user.id)),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Column(children: [
              const Icon(Icons.qr_code_scanner_rounded,
                  size: 48, color: AppColors.primary),
              const SizedBox(height: 12),
              Text('Mark Your Attendance',
                  style: TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 4),
              Text(
                'Tap below when your faculty has started a session.\n'
                'You must be inside the campus to scan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const ScannerScreen(),
                        fullscreenDialog: true),
                  ),
                  icon: const Icon(Icons.qr_code_rounded),
                  label: const Text('Open Scanner'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          historyAsync.when(
            loading: () => Column(children: List.generate(4,
                (_) => Padding(padding: const EdgeInsets.only(bottom: 10),
                    child: ShimmerBox(height: 70, radius: 12)))),
            error: (e, _) => Center(
                child: Text('Error loading history: $e',
                    style: TextStyle(color: AppColors.danger))),
            data: (records) {
              if (records.isEmpty) {
                return const EmptyState(
                  icon: Icons.fact_check_rounded,
                  title: 'No attendance yet',
                  subtitle: 'Your attendance records will appear here',
                );
              }

              final total = records.length;
              final present = records
                  .where((r) => r['status'] == 'present' || r['status'] == 'late')
                  .length;
              final pct = total > 0 ? (present / total * 100).round() : 0;

              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                GlassCard(
                  child: Row(children: [
                    _StatPill('Total', '$total', AppColors.primary),
                    _StatPill('Present', '$present', AppColors.success),
                    _StatPill('Attendance', '$pct%',
                        pct >= 75 ? AppColors.success : AppColors.danger),
                  ]),
                ),
                const SizedBox(height: 16),
                Text('Recent Records',
                    style: TextStyle(fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface, fontSize: 15)),
                const SizedBox(height: 10),
                ...records.take(30).map((r) {
                  final session = r['attendance_sessions'] as Map?;
                  final course = session?['courses'] as Map?;
                  final courseName = course?['name'] as String? ?? 'Unknown';
                  final courseCode = course?['code'] as String? ?? '';
                  final date = session != null
                      ? DateFormat('d MMM yyyy').format(
                          DateTime.parse(session['session_date'] as String))
                      : '';
                  final status = r['status'] as String? ?? 'absent';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: _statusColor(status).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_statusIcon(status),
                              color: _statusColor(status), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(courseName,
                              style: TextStyle(fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
                          Text('$courseCode · $date',
                              style: TextStyle(fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                        ])),
                        _StatusChip(status),
                      ]),
                    ),
                  );
                }),
              ]);
            },
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatPill(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
        color: color)),
    Text(label, style: TextStyle(fontSize: 11,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
  ]));
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: _statusColor(status).withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(status.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
            color: _statusColor(status))),
  );
}

Color _statusColor(String s) => switch (s) {
  'present' => AppColors.success,
  'late'    => AppColors.warning,
  'absent'  => AppColors.danger,
  'excused' => AppColors.info,
  _         => AppColors.textMuted,
};

IconData _statusIcon(String s) => switch (s) {
  'present' => Icons.check_circle_rounded,
  'late'    => Icons.schedule_rounded,
  'absent'  => Icons.cancel_rounded,
  'excused' => Icons.info_rounded,
  _         => Icons.help_rounded,
};
