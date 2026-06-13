import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/db_service.dart';
import '../../../shared/widgets/widgets.dart';

const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const _daysFull = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const _types = ['lecture', 'lab', 'tutorial'];

class TimetableEntriesScreen extends StatefulWidget {
  final Timetable timetable;
  const TimetableEntriesScreen({super.key, required this.timetable});

  @override
  State<TimetableEntriesScreen> createState() => _TimetableEntriesScreenState();
}

class _TimetableEntriesScreenState extends State<TimetableEntriesScreen> {
  List<TimetableEntry> _entries = [];
  List<Course> _courses = [];
  List<Profile> _faculty = [];
  List<Classroom> _classrooms = [];
  bool _loading = true;
  int _selectedDay = DateTime.now().weekday % 7;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Future.wait([
        DbService.getEntriesForTimetable(widget.timetable.id),
        DbService.getCourses(),
        DbService.getFacultyList(),
        DbService.getClassrooms(),
      ]);
      if (mounted) setState(() {
        _entries    = r[0] as List<TimetableEntry>;
        _courses    = r[1] as List<Course>;
        _faculty    = r[2] as List<Profile>;
        _classrooms = r[3] as List<Classroom>;
        _loading    = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<TimetableEntry> get _dayEntries =>
      _entries.where((e) => e.dayOfWeek == _selectedDay).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

  void _showEntryForm({TimetableEntry? entry}) {
    String? courseId    = entry?.courseId;
    String? facultyId   = entry?.facultyId;
    String? classroomId = entry?.classroomId;
    int     day         = entry?.dayOfWeek ?? _selectedDay;
    String  type        = entry?.sessionType ?? 'lecture';
    String? group       = entry?.studentGroup;

    final startCtrl = TextEditingController(
        text: entry?.startTime.substring(0, 5) ?? '09:00');
    final endCtrl   = TextEditingController(
        text: entry?.endTime.substring(0, 5) ?? '10:00');
    final groupCtrl = TextEditingController(text: group ?? '');

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(entry == null ? 'Add Class Slot' : 'Edit Class Slot',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<int>(
                  value: day,
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  decoration: _deco('Day'),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  items: List.generate(7, (i) => DropdownMenuItem(value: i,
                      child: Text(_daysFull[i]))),
                  onChanged: (v) => setSt(() => day = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: courseId,
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  isExpanded: true,
                  decoration: _deco('Course *'),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                  items: _courses.map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Text('${c.code} – ${c.name}',
                          overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setSt(() => courseId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: facultyId,
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  isExpanded: true,
                  decoration: _deco('Faculty'),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— None —')),
                    ..._faculty.map((f) => DropdownMenuItem(
                        value: f.id, child: Text(f.fullName, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) => setSt(() => facultyId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: classroomId,
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  isExpanded: true,
                  decoration: _deco('Classroom'),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— None —')),
                    ..._classrooms.map((r) => DropdownMenuItem(
                        value: r.id,
                        child: Text('${r.name}${r.building != null ? ' (${r.building})' : ''}',
                            overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) => setSt(() => classroomId = v),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _timeField(startCtrl, 'Start Time', ctx)),
                  const SizedBox(width: 12),
                  Expanded(child: _timeField(endCtrl, 'End Time', ctx)),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  decoration: _deco('Session Type'),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  items: _types.map((t) => DropdownMenuItem(
                      value: t, child: Text(t[0].toUpperCase() + t.substring(1)))).toList(),
                  onChanged: (v) => setSt(() => type = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: groupCtrl,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: _deco('Student Group (e.g. CSE-A, optional)'),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38))),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                if (courseId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a course.')));
                  return;
                }
                final data = {
                  'timetable_id': widget.timetable.id,
                  'course_id':    courseId,
                  'faculty_id':   facultyId,
                  'classroom_id': classroomId,
                  'day_of_week':  day,
                  'start_time':   '${startCtrl.text}:00',
                  'end_time':     '${endCtrl.text}:00',
                  'session_type': type,
                  'student_group': groupCtrl.text.trim().isEmpty ? null : groupCtrl.text.trim(),
                };
                try {
                  if (entry == null) {
                    await DbService.createTimetableEntry(data);
                  } else {
                    await DbService.updateTimetableEntry(entry.id, data);
                  }
                  if (ctx.mounted) { Navigator.pop(ctx); _load(); }
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text(entry == null ? 'Add' : 'Save'),
            ),
          ],
        );
      }),
    );
  }

  InputDecoration _deco(String label) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
    filled: true,
    fillColor: Theme.of(context).colorScheme.surface,
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Theme.of(context).dividerColor)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Theme.of(context).dividerColor)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  Widget _timeField(TextEditingController ctrl, String label, BuildContext ctx) =>
      TextFormField(
        controller: ctrl,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        decoration: _deco(label),
        readOnly: true,
        onTap: () async {
          final parts = ctrl.text.split(':');
          final picked = await showTimePicker(
            context: ctx,
            initialTime: TimeOfDay(
                hour: int.tryParse(parts[0]) ?? 9,
                minute: int.tryParse(parts[1]) ?? 0),
          );
          if (picked != null) {
            ctrl.text =
                '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
          }
        },
      );

  Future<void> _delete(TimetableEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Delete Slot?', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
            'Remove ${e.course?.name ?? 'this slot'} on ${_daysFull[e.dayOfWeek]}?',
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
    if (ok == true) {
      await DbService.deleteTimetableEntry(e.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPublished = widget.timetable.status == 'published';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.timetable.name,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface)),
          Text('${widget.timetable.academicYear} · ${widget.timetable.semester} · '
              '${widget.timetable.status.toUpperCase()}',
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
        ]),
        actions: [
          if (!isPublished)
            TextButton.icon(
              onPressed: () async {
                await DbService.publishTimetable(widget.timetable.id);
                if (mounted) Navigator.pop(context, true);
              },
              icon: const Icon(Icons.publish_rounded, color: AppColors.success, size: 18),
              label: const Text('Publish', style: TextStyle(color: AppColors.success)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showEntryForm,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Add Slot'),
      ),
      body: Column(children: [
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: List.generate(7, (i) {
              final count = _entries.where((e) => e.dayOfWeek == i).length;
              final active = _selectedDay == i;
              return Expanded(child: GestureDetector(
                onTap: () => setState(() => _selectedDay = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_days[i],
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: active ? Colors.white : AppColors.textSecondary)),
                    if (count > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: active ? Colors.white24 : AppColors.primary.withAlpha(40),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('$count',
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w700,
                                color: active ? Colors.white : AppColors.primary)),
                      ),
                  ]),
                ),
              ));
            }),
          ),
        ),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _dayEntries.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.event_busy_rounded, size: 48, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38)),
                const SizedBox(height: 12),
                Text('No classes on ${_daysFull[_selectedDay]}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 15)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _showEntryForm,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add a slot'),
                ),
              ]))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemCount: _dayEntries.length,
                itemBuilder: (_, idx) => _EntryCard(
                  entry: _dayEntries[idx],
                  onEdit: () => _showEntryForm(entry: _dayEntries[idx]),
                  onDelete: () => _delete(_dayEntries[idx]),
                ),
              ),
        ),
      ]),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final TimetableEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _EntryCard({required this.entry, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final typeColor = switch (entry.sessionType) {
      'lab'      => AppColors.warning,
      'tutorial' => AppColors.info,
      _          => AppColors.primary,
    };
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 62,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: typeColor.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            Text(entry.startTime.substring(0, 5),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: typeColor)),
            Container(height: 1, width: 28,
                margin: const EdgeInsets.symmetric(vertical: 3),
                color: typeColor.withAlpha(80)),
            Text(entry.endTime.substring(0, 5),
                style: TextStyle(fontSize: 11, color: typeColor.withAlpha(200))),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(entry.course?.name ?? 'Unknown Course',
              style: TextStyle(fontWeight: FontWeight.w700,
                  fontSize: 14, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 3),
          Wrap(spacing: 8, runSpacing: 4, children: [
            if (entry.course?.code != null)
              _Pill(entry.course!.code, AppColors.textMuted),
            if (entry.faculty != null)
              _Pill('👤 ${entry.faculty!.fullName}', AppColors.info),
            if (entry.classroom != null)
              _Pill('📍 ${entry.classroom!.name}', AppColors.textMuted),
            if (entry.studentGroup != null)
              _Pill('🏷 ${entry.studentGroup!}', AppColors.warning),
            _Pill(entry.sessionType, typeColor),
          ]),
        ])),
        Column(children: [
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 20, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38)),
            onPressed: onEdit,
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
            onPressed: onDelete,
            tooltip: 'Delete',
          ),
        ]),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withAlpha(25),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
  );
}
