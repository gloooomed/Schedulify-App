import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/db_service.dart';
import '../../../shared/widgets/widgets.dart';

class CoursesTab extends StatefulWidget {
  const CoursesTab({super.key});
  @override
  State<CoursesTab> createState() => _CoursesTabState();
}

class _CoursesTabState extends State<CoursesTab> {
  List<Course> _items = [];
  List<Department> _depts = [];
  String? _filterDept;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Future.wait([DbService.getCourses(), DbService.getDepartments()]);
      setState(() {
        _items = r[0] as List<Course>;
        _depts = r[1] as List<Department>;
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  List<Course> get _filtered => _filterDept == null
      ? _items
      : _items.where((c) => c.departmentId == _filterDept).toList();

  void _showForm({Course? course}) {
    final name = TextEditingController(text: course?.name);
    final code = TextEditingController(text: course?.code);
    final credits = TextEditingController(text: course?.credits.toString() ?? '3');
    final sem = TextEditingController(text: course?.semester);
    String? deptId = course?.departmentId;
    bool isElective = course?.isElective ?? false;
    String courseType = course?.courseType ?? 'theory';

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(course == null ? 'Add Course' : 'Edit Course',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            AppTextField(controller: name, label: 'Course Name', prefixIcon: Icons.book_rounded),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: AppTextField(controller: code, label: 'Code',
                  prefixIcon: Icons.tag_rounded)),
              const SizedBox(width: 12),
              Expanded(child: AppTextField(controller: credits, label: 'Credits',
                  keyboardType: TextInputType.number, prefixIcon: Icons.star_outline)),
            ]),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: deptId,
              dropdownColor: AppColors.bgCard,
              decoration: InputDecoration(labelText: 'Department',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border)),
                  filled: true, fillColor: AppColors.glass),
              style: const TextStyle(color: AppColors.textPrimary),
              items: _depts.map((d) => DropdownMenuItem(value: d.id,
                  child: Text(d.name))).toList(),
              onChanged: (v) => setSt(() => deptId = v),
            ),
            const SizedBox(height: 14),
            AppTextField(controller: sem, label: 'Semester (optional)', prefixIcon: Icons.calendar_today_rounded),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                value: courseType,
                dropdownColor: AppColors.bgCard,
                decoration: InputDecoration(labelText: 'Type',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border)),
                    filled: true, fillColor: AppColors.glass),
                style: const TextStyle(color: AppColors.textPrimary),
                items: ['theory', 'lab', 'tutorial'].map((t) =>
                    DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(),
                onChanged: (v) => setSt(() => courseType = v!),
              )),
              const SizedBox(width: 12),
              Row(children: [
                Checkbox(value: isElective, activeColor: AppColors.primary,
                    onChanged: (v) => setSt(() => isElective = v!)),
                const Text('Elective', style: TextStyle(color: AppColors.textSecondary)),
              ]),
            ]),
            const SizedBox(height: 20),
            PrimaryButton(label: course == null ? 'Create' : 'Update',
                width: double.infinity,
                onPressed: () async {
                  final data = {
                    'name': name.text.trim(), 'code': code.text.trim().toUpperCase(),
                    'credits': int.tryParse(credits.text) ?? 3,
                    'department_id': deptId, 'semester': sem.text.isEmpty ? null : sem.text,
                    'course_type': courseType, 'is_elective': isElective,
                  };
                  try {
                    if (course == null) await DbService.createCourse(data);
                    else await DbService.updateCourse(course.id, data);
                    if (mounted) { Navigator.pop(context); _load(); }
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }),
          ])),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        backgroundColor: AppColors.primary, child: const Icon(Icons.add)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PageHeader(title: 'Courses', subtitle: '${filtered.length} courses'),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _FilterChip(label: 'All', selected: _filterDept == null,
                  onTap: () => setState(() => _filterDept = null)),
              ..._depts.map((d) => _FilterChip(label: d.name, selected: _filterDept == d.id,
                  onTap: () => setState(() => _filterDept = d.id))),
            ]),
          ),
          const SizedBox(height: 16),
          if (_loading)
            ...List.generate(4, (_) => Padding(padding: const EdgeInsets.only(bottom: 10),
                child: ShimmerBox(height: 70, radius: 14)))
          else if (filtered.isEmpty)
            EmptyState(icon: Icons.book_rounded, title: 'No courses', subtitle: 'Tap + to add')
          else
            ...filtered.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                child: Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: c.isElective ? AppColors.warning.withOpacity(0.15)
                            : AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(c.code, style: TextStyle(
                          color: c.isElective ? AppColors.warning : AppColors.primary,
                          fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                    Text('${c.credits} Credits · ${c.courseType.toUpperCase()}'
                        '${c.department != null ? ' · ${c.department!.code}' : ''}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ])),
                  IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.textMuted, size: 18),
                      onPressed: () => _showForm(course: c)),
                  IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                      onPressed: () async { await DbService.deleteCourse(c.id); _load(); }),
                ]),
              ),
            )),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.glass,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(label, style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
      ),
    ),
  );
}
