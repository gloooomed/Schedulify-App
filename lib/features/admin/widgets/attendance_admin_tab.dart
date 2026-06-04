import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/attendance_models.dart';
import '../../../services/attendance_service.dart';
import '../../../shared/widgets/widgets.dart';

class AttendanceAdminTab extends ConsumerStatefulWidget {
  const AttendanceAdminTab({super.key});

  @override
  ConsumerState<AttendanceAdminTab> createState() => _AttendanceAdminTabState();
}

class _AttendanceAdminTabState extends ConsumerState<AttendanceAdminTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Live Sessions'),
            Tab(text: 'History'),
          ],
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [
              _LiveSessionsView(),
              _SessionHistoryView(),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }
}

// ── Live Sessions ───────────────────────────────────────────

class _LiveSessionsView extends ConsumerWidget {
  const _LiveSessionsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(activeSessionsProvider);

    return sessionsAsync.when(
      loading: () => ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(3,
            (_) => Padding(padding: const EdgeInsets.only(bottom: 10),
                child: ShimmerBox(height: 90, radius: 14))),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (sessions) {
        if (sessions.isEmpty) {
          return const EmptyState(
            icon: Icons.sensors_off_rounded,
            title: 'No active sessions',
            subtitle: 'Live sessions will appear here when faculty start them',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(activeSessionsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (_, i) => _SessionCard(session: sessions[i]),
          ),
        );
      },
    );
  }
}

class _SessionCard extends ConsumerWidget {
  final AttendanceSession session;
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendeesAsync = ref.watch(sessionAttendeesProvider(session.id));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(session.courseName ?? 'Unknown Course',
                    style: const TextStyle(fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary, fontSize: 15)),
                Text(
                  'Started ${DateFormat('h:mm a').format(session.startedAt.toLocal())}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ]),
            ),
            // Live count badge
            attendeesAsync.when(
              data: (records) => _CountBadge(records.length),
              loading: () => _CountBadge(0),
              error: (_, __) => _CountBadge(0),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _ActionButton(
              label: 'View Records',
              icon: Icons.list_alt_rounded,
              color: AppColors.primary,
              onTap: () => _showRecordsSheet(context, session),
            ),
            const SizedBox(width: 8),
            _ActionButton(
              label: 'Terminate',
              icon: Icons.stop_circle_rounded,
              color: AppColors.danger,
              onTap: () => _terminateDialog(context, ref, session),
            ),
          ]),
        ]),
      ),
    );
  }

  void _showRecordsSheet(BuildContext context, AttendanceSession session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _RecordsSheet(session: session),
    );
  }

  void _terminateDialog(BuildContext context, WidgetRef ref,
      AttendanceSession session) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Terminate Session',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('This will end the session immediately. All present records are kept.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          AppTextField(
            controller: reasonCtrl,
            label: 'Reason (required)',
            prefixIcon: Icons.note_alt_rounded,
            maxLines: 2,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (reasonCtrl.text.trim().length < 10) return;
              final user =
                  ProviderScope.containerOf(context).read(currentUserProvider);
              await AttendanceService.adminTerminateSession(
                sessionId: session.id,
                adminId: user!.id,
                reason: reasonCtrl.text.trim(),
              );
              if (context.mounted) {
                Navigator.pop(context);
                ProviderScope.containerOf(context)
                    .invalidate(activeSessionsProvider);
              }
            },
            child: const Text('Terminate',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge(this.count);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.success.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.people_rounded, size: 14, color: AppColors.success),
      const SizedBox(width: 4),
      Text('$count present',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: AppColors.success)),
    ]),
  );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.icon,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 14, color: color),
    label: Text(label, style: TextStyle(color: color, fontSize: 12)),
    style: OutlinedButton.styleFrom(
      side: BorderSide(color: color.withOpacity(0.5)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
  );
}

// ── Records Sheet ───────────────────────────────────────────

class _RecordsSheet extends StatefulWidget {
  final AttendanceSession session;
  const _RecordsSheet({required this.session});

  @override
  State<_RecordsSheet> createState() => _RecordsSheetState();
}

class _RecordsSheetState extends State<_RecordsSheet> {
  List<AttendanceRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records =
        await AttendanceService.getSessionRecords(widget.session.id);
    if (mounted) setState(() { _records = records; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Column(children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Text(widget.session.courseName ?? 'Session Records',
                style: const TextStyle(fontWeight: FontWeight.w700,
                    fontSize: 16, color: AppColors.textPrimary)),
            const Spacer(),
            Text('${_records.length} students',
                style: const TextStyle(color: AppColors.textSecondary,
                    fontSize: 13)),
          ]),
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _records.length,
              itemBuilder: (_, i) {
                final r = _records[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: _statusColor(r.status).withOpacity(0.15),
                    child: Icon(_statusIcon(r.status),
                        color: _statusColor(r.status), size: 18),
                  ),
                  title: Text(r.studentName ?? r.studentId,
                      style: const TextStyle(color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(r.rollNumber ?? '',
                      style: const TextStyle(color: AppColors.textSecondary,
                          fontSize: 12)),
                  trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                    _StatusChip(r.status),
                    if (r.isOverride)
                      const Text('override',
                          style: TextStyle(fontSize: 10,
                              color: AppColors.warning)),
                  ]),
                  onTap: () => _overrideDialog(context, r),
                );
              },
            ),
          ),
      ]),
    );
  }

  void _overrideDialog(BuildContext context, AttendanceRecord record) {
    String selected = record.status;
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: Text('Override: ${record.studentName ?? 'Student'}',
              style: const TextStyle(color: AppColors.textPrimary)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButton<String>(
              value: selected,
              dropdownColor: AppColors.bgCard,
              items: ['present', 'absent', 'late', 'excused']
                  .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.toUpperCase(),
                          style: TextStyle(color: _statusColor(s)))))
                  .toList(),
              onChanged: (v) => setSt(() => selected = v!),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: reasonCtrl,
              label: 'Reason (min 10 chars)',
              prefixIcon: Icons.note_rounded,
              maxLines: 2,
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                if (reasonCtrl.text.trim().length < 10) return;
                final user = ProviderScope.containerOf(context)
                    .read(currentUserProvider);
                await AttendanceService.adminOverride(
                  recordId: record.id,
                  sessionId: record.sessionId,
                  adminId: user!.id,
                  newStatus: selected,
                  reason: reasonCtrl.text.trim(),
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  _load();
                }
              },
              child: const Text('Save Override',
                  style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Session History ─────────────────────────────────────────

class _SessionHistoryView extends StatefulWidget {
  const _SessionHistoryView();

  @override
  State<_SessionHistoryView> createState() => _SessionHistoryViewState();
}

class _SessionHistoryViewState extends State<_SessionHistoryView> {
  List<AttendanceSession> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await AttendanceService.getSessionHistory(limit: 50);
    if (mounted) setState(() { _sessions = sessions; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(5,
            (_) => Padding(padding: const EdgeInsets.only(bottom: 10),
                child: ShimmerBox(height: 70, radius: 14))),
      );
    }
    if (_sessions.isEmpty) {
      return const EmptyState(
        icon: Icons.history_rounded,
        title: 'No session history',
        subtitle: 'Past attendance sessions will appear here',
      );
    }
    return RefreshIndicator(
      onRefresh: () async { setState(() => _loading = true); await _load(); },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sessions.length,
        itemBuilder: (_, i) {
          final s = _sessions[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(s.courseName ?? 'Unknown Course',
                      style: const TextStyle(fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  Text(
                    '${DateFormat('d MMM yyyy').format(s.sessionDate)} · '
                    '${DateFormat('h:mm a').format(s.startedAt.toLocal())}',
                    style: const TextStyle(fontSize: 12,
                        color: AppColors.textSecondary),
                  ),
                ])),
                _StatusChip(s.status),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: _statusColor(status).withOpacity(0.15),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(status.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
            color: _statusColor(status))),
  );
}

Color _statusColor(String status) => switch (status) {
      'present' || 'active' => AppColors.success,
      'late'    => AppColors.warning,
      'absent'  => AppColors.danger,
      'excused' => AppColors.info,
      'ended'   => AppColors.textMuted,
      _         => AppColors.textMuted,
    };

IconData _statusIcon(String status) => switch (status) {
      'present' => Icons.check_circle_rounded,
      'late'    => Icons.schedule_rounded,
      'absent'  => Icons.cancel_rounded,
      'excused' => Icons.info_rounded,
      _         => Icons.help_rounded,
    };

// ignore: unused_element
const _success = AppColors.success;
