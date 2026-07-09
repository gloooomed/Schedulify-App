import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/db_service.dart';
import '../../../shared/widgets/widgets.dart';

class OverviewTab extends StatefulWidget {
  const OverviewTab({super.key});

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  Map<String, int>? _stats;
  Map<String, dynamic>? _analytics;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final stats     = await DbService.getDashboardStats();
      final analytics = await DbService.getAttendanceAnalytics();
      setState(() {
        _stats     = stats;
        _analytics = analytics;
        _loading   = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return ErrorView(
        message: 'Could not load dashboard stats.',
        onRetry: _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const PageHeader(title: 'Overview', subtitle: 'System health and statistics'),
          const SizedBox(height: 24),
          if (_loading) ...[
            LayoutBuilder(builder: (_, c) {
              final cols = c.maxWidth > 600 ? 4 : 2;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: cols,
                crossAxisSpacing: 12, mainAxisSpacing: 12,
                childAspectRatio: c.maxWidth > 600 ? 1.4 : 1.2,
                children: List.generate(4, (_) => ShimmerBox(height: 80, radius: 16)),
              );
            }),
            const SizedBox(height: 28),
            const SkeletonCard(height: 120),
            const SizedBox(height: 16),
            const SkeletonCard(height: 200),
          ] else ...[
            _statGrid(),
            const SizedBox(height: 20),
            _analyticsRow(),
            const SizedBox(height: 20),
            if ((_analytics?['lowStudents'] as List?)?.isNotEmpty ?? false) ...[
              _lowAttendanceCard(),
              const SizedBox(height: 20),
            ],
            _systemStatusCard(),
          ],
        ],
      ),
    );
  }

  Widget _statGrid() {
    final items = [
      ('Departments', '${_stats?['departments'] ?? 0}', Icons.domain_rounded,      AppColors.primary),
      ('Courses',     '${_stats?['courses'] ?? 0}',     Icons.menu_book_rounded,    AppColors.info),
      ('Classrooms',  '${_stats?['classrooms'] ?? 0}',  Icons.meeting_room_rounded, AppColors.warning),
      ('Users',       '${_stats?['users'] ?? 0}',       Icons.groups_rounded,       AppColors.success),
    ];
    return LayoutBuilder(builder: (_, constraints) {
      final isWide = constraints.maxWidth > 600;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isWide ? 4 : 2,
          crossAxisSpacing: 12, mainAxisSpacing: 12,
          childAspectRatio: isWide ? 1.4 : 1.2,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => StatCard(
          label: items[i].$1, value: items[i].$2,
          icon: items[i].$3, color: items[i].$4,
        ),
      );
    });
  }

  Widget _analyticsRow() {
    final overallRate = (_analytics?['overallRate'] as double? ?? 0).toStringAsFixed(1);
    final lowCount    = _analytics?['lowAttendanceCount'] as int? ?? 0;

    return Row(children: [
      Expanded(
        child: StatCard(
          label: 'Overall Attendance',
          value: '$overallRate%',
          icon: Icons.bar_chart_rounded,
          color: double.tryParse(overallRate)! >= 75
              ? AppColors.success
              : AppColors.danger,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: StatCard(
          label: 'Below 75% Attendance',
          value: '$lowCount students',
          icon: Icons.warning_amber_rounded,
          color: lowCount > 0 ? AppColors.warning : AppColors.success,
        ),
      ),
    ]);
  }

  Widget _lowAttendanceCard() {
    final students = (_analytics?['lowStudents'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
          const SizedBox(width: 8),
          Text('Low Attendance Alert',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                  color: context.textPrimary)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('< 75%',
                style: const TextStyle(color: AppColors.warning, fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 14),
        ...students.map((s) {
          final pct = s['pct'] as int? ?? 0;
          final color = pct < 60 ? AppColors.danger : AppColors.warning;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: color.withOpacity(0.12),
                child: Text(
                  (s['name'] as String? ?? '?').isNotEmpty
                      ? (s['name'] as String)[0].toUpperCase()
                      : '?',
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(s['name'] as String? ?? 'Unknown',
                    style: TextStyle(color: context.textPrimary, fontSize: 13)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('$pct%',
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ]),
          );
        }),
        if ((_analytics?['lowAttendanceCount'] as int? ?? 0) > students.length)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '+ ${(_analytics?['lowAttendanceCount'] as int) - students.length} more students',
              style: TextStyle(fontSize: 12, color: context.textMuted),
            ),
          ),
      ]),
    );
  }

  Widget _systemStatusCard() {
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('System Status', style: TextStyle(fontSize: 16,
            fontWeight: FontWeight.w700, color: context.textPrimary)),
        const SizedBox(height: 16),
        _statusRow('Database',        true),
        _statusRow('Supabase Auth',   true),
        _statusRow('Active Timetable',
            (_stats?['activeTimetables'] ?? 0) > 0),
      ]),
    );
  }

  Widget _statusRow(String label, bool ok) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: ok ? AppColors.success : AppColors.danger, size: 18),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: context.textPrimary, fontSize: 14)),
        const Spacer(),
        Text(ok ? 'Operational' : 'Issue detected',
            style: TextStyle(
                color: ok ? AppColors.success : AppColors.danger,
                fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
