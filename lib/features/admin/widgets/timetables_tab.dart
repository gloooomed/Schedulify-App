import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../models/models.dart';
import '../../../services/db_service.dart';
import '../../../shared/widgets/widgets.dart';
import 'timetable_entries_screen.dart';

class TimetablesTab extends ConsumerStatefulWidget {
  const TimetablesTab({super.key});
  @override
  ConsumerState<TimetablesTab> createState() => _TimetablesTabState();
}

class _TimetablesTabState extends ConsumerState<TimetablesTab> {
  List<Timetable> _items = [];
  List<Department> _depts = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Future.wait([DbService.getTimetables(), DbService.getDepartments()]);
      if (mounted) setState(() {
        _items = r[0] as List<Timetable>;
        _depts = r[1] as List<Department>;
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _showForm({Timetable? tt}) {
    final name = TextEditingController(text: tt?.name);
    final year = TextEditingController(text: tt?.academicYear ?? '2025-26');
    final sem  = TextEditingController(text: tt?.semester ?? '');
    String? deptId = tt?.departmentId;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tt == null ? 'New Timetable' : 'Edit Timetable',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface)),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AppTextField(controller: name, label: 'Timetable Name',
                hint: 'CSE Sem 3 2025', prefixIcon: Icons.calendar_month_rounded),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: AppTextField(controller: year, label: 'Academic Year', hint: '2025-26')),
              const SizedBox(width: 12),
              Expanded(child: AppTextField(controller: sem, label: 'Semester', hint: '3')),
            ]),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: deptId, dropdownColor: Theme.of(context).colorScheme.surface,
              decoration: InputDecoration(
                labelText: 'Department',
                labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                filled: true, fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              items: [
                DropdownMenuItem(value: null, child: Text('— All Departments —',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38)))),
                ..._depts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
              ],
              onChanged: (v) => setSt(() => deptId = v),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38)))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              final user = ref.read(currentUserProvider);
              final data = {
                'name': name.text.trim(),
                'academic_year': year.text.trim(),
                'semester': sem.text.trim(),
                'department_id': deptId,
                'generated_by': user?.id,
              };
              try {
                if (tt == null) await DbService.createTimetable(data);
                else await DbService.updateTimetable(tt.id, data);
                if (mounted) { Navigator.pop(ctx); _load(); }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: Text(tt == null ? 'Create' : 'Update'),
          ),
        ],
      )),
    );
  }

  Future<void> _confirmDelete(Timetable tt) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Delete Timetable?',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text('This will delete "${tt.name}" and all its class slots.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) { await DbService.deleteTimetable(tt.id); _load(); }
  }

  Color _statusColor(String s) => switch (s) {
    'published' => AppColors.success,
    'archived'  => AppColors.textMuted,
    _           => AppColors.warning,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('New Timetable'),
      ),
      body: RefreshIndicator(
        onRefresh: _load, color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            PageHeader(title: 'Timetables',
                subtitle: '${_items.length} timetable${_items.length == 1 ? '' : 's'}'),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.info.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withAlpha(60)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded, color: AppColors.info, size: 18),
                SizedBox(width: 10),
                Expanded(child: Text(
                  'Create a timetable, then tap it to add class slots (course, faculty, time, room).',
                  style: TextStyle(color: AppColors.info, fontSize: 13),
                )),
              ]),
            ),
            if (_loading)
              ...List.generate(3, (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ShimmerBox(height: 120, radius: 16)))
            else if (_items.isEmpty)
              EmptyState(icon: Icons.calendar_month_rounded,
                  title: 'No timetables yet',
                  subtitle: 'Tap "New Timetable" to get started')
            else
              ..._items.map((tt) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _TimetableCard(
                  tt: tt,
                  statusColor: _statusColor(tt.status),
                  onEdit: () => _showForm(tt: tt),
                  onDelete: () => _confirmDelete(tt),
                  onPublish: () async {
                    try {
                      await DbService.publishTimetable(tt.id);
                      _load();
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Publish failed: $e'),
                              backgroundColor: AppColors.danger));
                    }
                  },
                  onArchive: () async {
                    try {
                      await DbService.archiveTimetable(tt.id);
                      _load();
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Archive failed: $e'),
                              backgroundColor: AppColors.danger));
                    }
                  },
                  onOpenEntries: () async {
                    final refresh = await Navigator.push<bool>(context,
                        MaterialPageRoute(
                            builder: (_) => TimetableEntriesScreen(timetable: tt)));
                    if (refresh == true) _load();
                  },
                ),
              )),
          ],
        ),
      ),
    );
  }
}

class _TimetableCard extends StatelessWidget {
  final Timetable tt;
  final Color statusColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPublish;
  final VoidCallback onArchive;
  final VoidCallback onOpenEntries;

  const _TimetableCard({
    required this.tt,
    required this.statusColor,
    required this.onEdit,
    required this.onDelete,
    required this.onPublish,
    required this.onArchive,
    required this.onOpenEntries,
  });

  @override
  Widget build(BuildContext context) => GlassCard(
    onTap: onOpenEntries,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: statusColor.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.calendar_month_rounded, color: statusColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tt.name, style: TextStyle(fontWeight: FontWeight.w700,
              fontSize: 15, color: Theme.of(context).colorScheme.onSurface)),
          Text('${tt.academicYear} · Sem ${tt.semester}'
              '${tt.department != null ? ' · ${tt.department!.name}' : ''}',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(tt.status.toUpperCase(),
              style: TextStyle(color: statusColor,
                  fontSize: 10, fontWeight: FontWeight.w700)),
        ),
      ]),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withAlpha(50)),
        ),
        child: const Row(children: [
          Icon(Icons.table_chart_rounded, color: AppColors.primary, size: 16),
          SizedBox(width: 8),
          Text('Tap to manage class slots →',
              style: TextStyle(color: AppColors.primary, fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        if (tt.status == 'draft')
          _ActionBtn('Publish', Icons.publish_rounded, AppColors.success, onPublish),
        if (tt.status == 'published')
          _ActionBtn('Archive', Icons.archive_rounded, AppColors.warning, onArchive),
        const Spacer(),
        IconButton(
            icon: Icon(Icons.edit_outlined, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38), size: 20),
            onPressed: onEdit, tooltip: 'Edit'),
        IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
            onPressed: onDelete, tooltip: 'Delete'),
      ]),
    ]),
  );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(this.label, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}
