import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/db_service.dart';
import '../../../shared/widgets/widgets.dart';

class DepartmentsTab extends StatefulWidget {
  const DepartmentsTab({super.key});
  @override
  State<DepartmentsTab> createState() => _DepartmentsTabState();
}

class _DepartmentsTabState extends State<DepartmentsTab> {
  List<Department> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await DbService.getDepartments();
      setState(() { _items = data; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  void _showForm({Department? dept}) {
    final name = TextEditingController(text: dept?.name);
    final code = TextEditingController(text: dept?.code);
    final desc = TextEditingController(text: dept?.description);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(dept == null ? 'Add Department' : 'Edit Department',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 20),
          AppTextField(controller: name, label: 'Department Name',
              hint: 'Computer Science', prefixIcon: Icons.business_rounded),
          const SizedBox(height: 14),
          AppTextField(controller: code, label: 'Code',
              hint: 'CS', prefixIcon: Icons.tag_rounded),
          const SizedBox(height: 14),
          AppTextField(controller: desc, label: 'Description (optional)',
              prefixIcon: Icons.notes_rounded, maxLines: 2),
          const SizedBox(height: 20),
          PrimaryButton(
            label: dept == null ? 'Create' : 'Update',
            width: double.infinity,
            onPressed: () async {
              try {
                final data = {
                  'name': name.text.trim(),
                  'code': code.text.trim().toUpperCase(),
                  if (desc.text.isNotEmpty) 'description': desc.text.trim(),
                };
                if (dept == null) {
                  await DbService.createDepartment(data);
                } else {
                  await DbService.updateDepartment(dept.id, data);
                }
                if (mounted) { Navigator.pop(context); _load(); }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())));
              }
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            PageHeader(title: 'Departments', subtitle: '${_items.length} departments',
              action: IconButton(icon: Icon(Icons.refresh_rounded,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)), onPressed: _load),
            ),
            const SizedBox(height: 20),
            if (_loading)
              ...List.generate(3, (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ShimmerBox(height: 70, radius: 16)))
            else if (_items.isEmpty)
              EmptyState(icon: Icons.business_rounded,
                  title: 'No departments yet',
                  subtitle: 'Tap + to add your first department')
            else
              ..._items.map((d) => _DeptCard(dept: d,
                  onEdit: () => _showForm(dept: d),
                  onDelete: () async {
                    await DbService.deleteDepartment(d.id);
                    _load();
                  })),
          ],
        ),
      ),
    );
  }
}

class _DeptCard extends StatelessWidget {
  final Department dept;
  final VoidCallback onEdit, onDelete;
  const _DeptCard({required this.dept, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            constraints: const BoxConstraints(maxWidth: 72),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(dept.code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.primary,
                    fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(dept.name, style: TextStyle(fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface, fontSize: 15)),
            if (dept.head != null)
              Text('HOD: ${dept.head!.fullName}',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
          ])),
          IconButton(icon: Icon(Icons.edit_outlined,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38), size: 20), onPressed: onEdit),
          IconButton(icon: const Icon(Icons.delete_outline,
              color: AppColors.danger, size: 20), onPressed: onDelete),
        ]),
      ),
    );
  }
}
