import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/assignment_service.dart';
import '../../../shared/widgets/widgets.dart';

class AssignmentsAdminTab extends StatefulWidget {
  const AssignmentsAdminTab({super.key});
  @override
  State<AssignmentsAdminTab> createState() => _AssignmentsAdminTabState();
}

class _AssignmentsAdminTabState extends State<AssignmentsAdminTab> {
  List<Assignment> _assignments = [];
  List<Map<String, dynamic>> _compliance = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        AssignmentService.getAllAssignments(),
        AssignmentService.getComplianceStats(),
      ]);
      if (mounted) {
        setState(() {
          _assignments = results[0] as List<Assignment>;
          _compliance  = results[1] as List<Map<String, dynamic>>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: _loading
          ? _buildShimmer()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary cards
                _buildSummaryRow(),
                const SizedBox(height: 20),

                // Compliance chart
                if (_compliance.isNotEmpty) ...[
                  Text('Submission Compliance by Department',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary)),
                  const SizedBox(height: 12),
                  _ComplianceChart(rows: _compliance),
                  const SizedBox(height: 20),
                ],

                // Assignment list
                Text('All Assignments',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary)),
                const SizedBox(height: 12),
                if (_assignments.isEmpty)
                  const EmptyState(
                    icon: Icons.assignment_outlined,
                    title: 'No assignments posted yet',
                  )
                else
                  ..._assignments.map((a) => _AdminAssignmentRow(assignment: a)),
              ],
            ),
    );
  }

  Widget _buildSummaryRow() {
    final totalAssignments = _assignments.length;
    final totalSubs = _compliance.fold<int>(
        0, (sum, r) => sum + ((r['total_submissions'] as num?)?.toInt() ?? 0));
    final avgCompliance = _compliance.isEmpty
        ? 0.0
        : _compliance.fold<double>(
              0,
              (sum, r) =>
                  sum + ((r['compliance_rate'] as num?)?.toDouble() ?? 0),
            ) /
            _compliance.length;

    final items = [
      ('Total Assignments', totalAssignments.toString(), Icons.assignment_rounded, AppColors.primary),
      ('Total Submissions', totalSubs.toString(), Icons.upload_file_rounded, AppColors.info),
      ('Avg Compliance', '${avgCompliance.toStringAsFixed(1)}%', Icons.bar_chart_rounded, AppColors.success),
    ];
    return LayoutBuilder(builder: (_, c) {
      final isWide = c.maxWidth > 500;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isWide ? 3 : 1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isWide ? 1.6 : 3.5,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => StatCard(
          label: items[i].$1,
          value: items[i].$2,
          icon: items[i].$3,
          color: items[i].$4,
        ),
      );
    });
  }

  Widget _buildShimmer() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(5, (_) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ShimmerBox(height: 80, radius: 16),
      )),
    );
  }
}

// ── Compliance Bar Chart ──────────────────────────────────────────────────────

class _ComplianceChart extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _ComplianceChart({required this.rows});

  @override
  Widget build(BuildContext context) {
    final barGroups = rows.asMap().entries.map((e) {
      final rate = (e.value['compliance_rate'] as num?)?.toDouble() ?? 0;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: rate,
            color: rate >= 70
                ? AppColors.success
                : rate >= 40
                    ? AppColors.warning
                    : AppColors.danger,
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    }).toList();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            maxY: 100,
            barGroups: barGroups,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= rows.length) return const SizedBox.shrink();
                    final name = rows[idx]['department_name'] as String? ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        name.length > 6 ? name.substring(0, 6) : name,
                        style: TextStyle(fontSize: 10, color: context.textMuted),
                      ),
                    );
                  },
                  reservedSize: 28,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, _) => Text(
                    '${value.toInt()}%',
                    style: TextStyle(fontSize: 10, color: context.textMuted),
                  ),
                  reservedSize: 36,
                  interval: 25,
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, _, rod, __) {
                  final name = rows[group.x]['department_name'] as String? ?? '';
                  return BarTooltipItem(
                    '$name\n${rod.toY.toStringAsFixed(1)}%',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Admin assignment row ──────────────────────────────────────────────────────

class _AdminAssignmentRow extends StatelessWidget {
  final Assignment assignment;
  const _AdminAssignmentRow({required this.assignment});

  @override
  Widget build(BuildContext context) {
    final a = assignment;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.assignment_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary)),
              if (a.course != null)
                Text(a.course!.name,
                    style: TextStyle(fontSize: 12, color: context.textSecondary)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(DateFormat('d MMM').format(a.dueAt),
                style: TextStyle(
                    fontSize: 12,
                    color: a.isOverdue ? AppColors.danger : context.textMuted,
                    fontWeight: FontWeight.w600)),
            Text('${a.totalMarks} marks',
                style: TextStyle(fontSize: 11, color: context.textMuted)),
          ]),
        ]),
      ),
    );
  }
}
