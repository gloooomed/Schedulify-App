import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/assignment_service.dart';
import '../../../services/db_service.dart';
import '../../../shared/widgets/widgets.dart';

class FacultyAssignmentsScreen extends ConsumerStatefulWidget {
  const FacultyAssignmentsScreen({super.key});
  @override
  ConsumerState<FacultyAssignmentsScreen> createState() =>
      _FacultyAssignmentsScreenState();
}

class _FacultyAssignmentsScreenState
    extends ConsumerState<FacultyAssignmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Assignment> _assignments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final list = await AssignmentService.getFacultyAssignments(user.id);
      if (mounted) setState(() { _assignments = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar
        Container(
          color: context.surfaceColor,
          child: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'My Assignments'),
              Tab(text: 'Grading Queue'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _MyAssignmentsTab(
                assignments: _assignments,
                loading: _loading,
                onRefresh: _load,
                onCreated: _load,
              ),
              _GradingQueueTab(
                assignments: _assignments,
                loading: _loading,
                onRefresh: _load,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── My Assignments Tab ────────────────────────────────────────────────────────

class _MyAssignmentsTab extends ConsumerWidget {
  final List<Assignment> assignments;
  final bool loading;
  final Future<void> Function() onRefresh;
  final VoidCallback onCreated;

  const _MyAssignmentsTab({
    required this.assignments,
    required this.loading,
    required this.onRefresh,
    required this.onCreated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: RefreshIndicator(
          onRefresh: onRefresh,
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: PrimaryButton(
                      label: 'New Assignment',
                      icon: Icons.add_rounded,
                      onPressed: () => _showCreateSheet(context, ref, onCreated),
                    ),
                  ),
                ),
              ),
              if (loading)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ShimmerBox(height: 90, radius: 16),
                    ),
                    childCount: 4,
                  ),
                )
              else if (assignments.isEmpty)
                const SliverFillRemaining(
                  child: EmptyState(
                    icon: Icons.assignment_outlined,
                    title: 'No assignments yet',
                    subtitle: 'Tap "New Assignment" to post one.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _AssignmentRow(
                        assignment: assignments[i],
                        onDeleted: onRefresh,
                      ),
                      childCount: assignments.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref, VoidCallback onCreated) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CreateAssignmentSheet(
        facultyId: ref.read(currentUserProvider)!.id,
        onCreated: onCreated,
      ),
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  final Assignment assignment;
  final Future<void> Function() onDeleted;

  const _AssignmentRow({required this.assignment, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    final a = assignment;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.title,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: context.textPrimary)),
              const SizedBox(height: 4),
              if (a.course != null)
                Text(a.course!.name,
                    style: TextStyle(fontSize: 12, color: context.textSecondary)),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.schedule_rounded,
                    size: 13,
                    color: a.isOverdue ? AppColors.danger : context.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Due ${DateFormat('d MMM, hh:mm a').format(a.dueAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: a.isOverdue ? AppColors.danger : context.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.star_outline_rounded, size: 13, color: context.textMuted),
                const SizedBox(width: 4),
                Text('${a.totalMarks} marks',
                    style: TextStyle(fontSize: 12, color: context.textMuted)),
              ]),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.danger, size: 20),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Delete assignment?'),
                  content: Text('This will delete "${a.title}" and all submissions.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete',
                            style: TextStyle(color: AppColors.danger))),
                  ],
                ),
              );
              if (ok == true) {
                await AssignmentService.deleteAssignment(a.id);
                await onDeleted();
              }
            },
          ),
        ]),
      ),
    );
  }
}

// ── Grading Queue Tab ─────────────────────────────────────────────────────────

class _GradingQueueTab extends StatefulWidget {
  final List<Assignment> assignments;
  final bool loading;
  final Future<void> Function() onRefresh;

  const _GradingQueueTab({
    required this.assignments,
    required this.loading,
    required this.onRefresh,
  });

  @override
  State<_GradingQueueTab> createState() => _GradingQueueTabState();
}

class _GradingQueueTabState extends State<_GradingQueueTab> {
  // assignmentId -> list of submissions
  final Map<String, List<AssignmentSubmission>> _subs = {};
  final Set<String> _expanded = {};
  final Set<String> _loadingSubs = {};

  Future<void> _loadSubs(String assignmentId) async {
    if (_loadingSubs.contains(assignmentId)) return;
    setState(() => _loadingSubs.add(assignmentId));
    try {
      final subs = await AssignmentService.getSubmissionsForAssignment(assignmentId);
      if (mounted) setState(() { _subs[assignmentId] = subs; _loadingSubs.remove(assignmentId); });
    } catch (_) {
      if (mounted) setState(() => _loadingSubs.remove(assignmentId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: RefreshIndicator(
          onRefresh: widget.onRefresh,
          color: AppColors.primary,
          child: widget.loading
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: List.generate(3, (_) =>
                    Padding(padding: const EdgeInsets.only(bottom: 12),
                        child: ShimmerBox(height: 72, radius: 16))),
                )
              : widget.assignments.isEmpty
                  ? const EmptyState(
                      icon: Icons.grading_rounded,
                      title: 'No assignments to grade',
                      subtitle: 'Create assignments first.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: widget.assignments.length,
                      itemBuilder: (_, i) {
                        final a = widget.assignments[i];
                        final isExpanded = _expanded.contains(a.id);
                        final subs = _subs[a.id] ?? [];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GlassCard(
                            padding: EdgeInsets.zero,
                            child: Column(children: [
                              // Header
                              InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  setState(() {
                                    if (isExpanded) {
                                      _expanded.remove(a.id);
                                    } else {
                                      _expanded.add(a.id);
                                      _loadSubs(a.id);
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(a.title,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                  color: context.textPrimary)),
                                          if (a.course != null)
                                            Text(a.course!.name,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: context.textSecondary)),
                                        ],
                                      ),
                                    ),
                                    if (subs.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text('${subs.length} submitted',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w600)),
                                      ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      isExpanded
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      color: context.textMuted,
                                    ),
                                  ]),
                                ),
                              ),
                              // Submissions
                              if (isExpanded) ...[
                                Divider(height: 1, color: context.borderColor),
                                if (_loadingSubs.contains(a.id))
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: ShimmerBox(height: 48, radius: 10),
                                  )
                                else if (subs.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text('No submissions yet.',
                                        style: TextStyle(
                                            color: context.textMuted, fontSize: 13)),
                                  )
                                else
                                  ...subs.map((sub) => _SubmissionRow(
                                        submission: sub,
                                        assignment: a,
                                        onGraded: () => _loadSubs(a.id),
                                      )),
                              ],
                            ]),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}

class _SubmissionRow extends StatelessWidget {
  final AssignmentSubmission submission;
  final Assignment assignment;
  final VoidCallback onGraded;

  const _SubmissionRow({
    required this.submission,
    required this.assignment,
    required this.onGraded,
  });

  @override
  Widget build(BuildContext context) {
    final sub = submission;
    final studentName = sub.student?.fullName ?? 'Student';
    final rollNo = sub.student?.rollNumber;

    return InkWell(
      onTap: () => _showGradeSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.student.withOpacity(0.15),
            child: Text(
              studentName.isNotEmpty ? studentName[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: AppColors.student,
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(studentName,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary)),
              if (rollNo != null)
                Text(rollNo,
                    style: TextStyle(fontSize: 11, color: context.textMuted)),
              Text(DateFormat('d MMM, hh:mm a').format(sub.submittedAt),
                  style: TextStyle(fontSize: 11, color: context.textMuted)),
            ]),
          ),
          if (sub.isGraded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${sub.marksObtained}/${assignment.totalMarks}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.success,
                      fontWeight: FontWeight.w700)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Grade',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600)),
            ),
        ]),
      ),
    );
  }

  void _showGradeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _GradeSheet(
        submission: submission,
        assignment: assignment,
        onGraded: onGraded,
      ),
    );
  }
}

// ── Grade Sheet ───────────────────────────────────────────────────────────────

class _GradeSheet extends StatefulWidget {
  final AssignmentSubmission submission;
  final Assignment assignment;
  final VoidCallback onGraded;

  const _GradeSheet({
    required this.submission,
    required this.assignment,
    required this.onGraded,
  });

  @override
  State<_GradeSheet> createState() => _GradeSheetState();
}

class _GradeSheetState extends State<_GradeSheet> {
  late final TextEditingController _marksCtrl;
  late final TextEditingController _feedbackCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _marksCtrl = TextEditingController(
        text: widget.submission.marksObtained?.toString() ?? '');
    _feedbackCtrl = TextEditingController(text: widget.submission.feedback ?? '');
  }

  @override
  void dispose() {
    _marksCtrl.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final marks = int.tryParse(_marksCtrl.text.trim());
    if (marks == null) {
      setState(() => _error = 'Enter a valid number.');
      return;
    }
    if (marks < 0 || marks > widget.assignment.totalMarks) {
      setState(() => _error = 'Marks must be between 0 and ${widget.assignment.totalMarks}.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await AssignmentService.gradeSubmission(
        widget.submission.id,
        marks,
        _feedbackCtrl.text.trim().isEmpty ? null : _feedbackCtrl.text.trim(),
      );
      widget.onGraded();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.toString(); });
    }
  }

  Future<void> _openFile() async {
    final url = widget.submission.fileUrl;
    if (url == null) return;
    try {
      final signed = await AssignmentService.getSignedUrl(url);
      await launchUrl(Uri.parse(signed));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.submission;
    final a = widget.assignment;
    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Grade Submission',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary)),
          const SizedBox(height: 4),
          Text(sub.student?.fullName ?? '',
              style: TextStyle(fontSize: 14, color: context.textSecondary)),
          const SizedBox(height: 16),
          if (sub.fileUrl != null)
            OutlinedButton.icon(
              onPressed: _openFile,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(sub.fileName ?? 'View submission'),
            ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            ErrorContainer(message: _error!),
            const SizedBox(height: 12),
          ],
          AppTextField(
            controller: _marksCtrl,
            label: 'Marks (out of ${a.totalMarks})',
            keyboardType: TextInputType.number,
            prefixIcon: Icons.star_outline_rounded,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _feedbackCtrl,
            label: 'Feedback (optional)',
            maxLines: 3,
            prefixIcon: Icons.comment_outlined,
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Save Grade',
            width: double.infinity,
            isLoading: _saving,
            onPressed: _save,
            icon: Icons.check_rounded,
          ),
        ],
      ),
    );
  }
}

// ── Create Assignment Sheet ───────────────────────────────────────────────────

class _CreateAssignmentSheet extends ConsumerStatefulWidget {
  final String facultyId;
  final VoidCallback onCreated;

  const _CreateAssignmentSheet({
    required this.facultyId,
    required this.onCreated,
  });

  @override
  ConsumerState<_CreateAssignmentSheet> createState() => _CreateAssignmentSheetState();
}

class _CreateAssignmentSheetState extends ConsumerState<_CreateAssignmentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _marksCtrl = TextEditingController(text: '100');
  final _maxMbCtrl = TextEditingController(text: '10');

  List<Course> _courses = [];
  String? _selectedCourseId;
  DateTime? _dueAt;
  Set<String> _allowedTypes = {'pdf', 'docx', 'image', 'zip'};
  bool _saving = false;
  String? _error;

  static const _typeOptions = ['pdf', 'docx', 'image', 'zip'];

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _marksCtrl.dispose();
    _maxMbCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    try {
      final courses = await DbService.getCourses();
      if (mounted) setState(() => _courses = courses);
    } catch (_) {}
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 23, minute: 59),
    );
    if (time == null) return;
    setState(() => _dueAt = DateTime(
        date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _create() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCourseId == null) {
      setState(() => _error = 'Select a course.');
      return;
    }
    if (_dueAt == null) {
      setState(() => _error = 'Select a due date.');
      return;
    }
    if (_allowedTypes.isEmpty) {
      setState(() => _error = 'Select at least one file type.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await AssignmentService.createAssignment({
        'faculty_id': widget.facultyId,
        'course_id': _selectedCourseId,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'due_at': _dueAt!.toIso8601String(),
        'total_marks': int.tryParse(_marksCtrl.text) ?? 100,
        'allowed_types': _allowedTypes.toList(),
        'max_file_mb': int.tryParse(_maxMbCtrl.text) ?? 10,
      });
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, controller) => Form(
        key: _formKey,
        child: SingleChildScrollView(
          controller: controller,
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: context.borderColor,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('New Assignment',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary)),
              const SizedBox(height: 20),

              if (_error != null) ...[
                ErrorContainer(message: _error!),
                const SizedBox(height: 12),
              ],

              AppTextField(
                controller: _titleCtrl,
                label: 'Title',
                prefixIcon: Icons.title_rounded,
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _descCtrl,
                label: 'Description (optional)',
                maxLines: 3,
                prefixIcon: Icons.description_outlined,
              ),
              const SizedBox(height: 12),

              // Course dropdown
              DropdownButtonFormField<String>(
                value: _selectedCourseId,
                decoration: const InputDecoration(
                  labelText: 'Course',
                  prefixIcon: Icon(Icons.menu_book_rounded, size: 20),
                ),
                items: _courses.map((c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.name, overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (v) => setState(() => _selectedCourseId = v),
              ),
              const SizedBox(height: 12),

              // Due date
              GestureDetector(
                onTap: _pickDueDate,
                child: AbsorbPointer(
                  child: TextFormField(
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Due Date & Time',
                      prefixIcon: const Icon(Icons.schedule_rounded, size: 20),
                      hintText: _dueAt == null
                          ? 'Tap to pick'
                          : DateFormat('d MMM yyyy, hh:mm a').format(_dueAt!),
                    ),
                    controller: TextEditingController(
                      text: _dueAt == null
                          ? ''
                          : DateFormat('d MMM yyyy, hh:mm a').format(_dueAt!),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Row(children: [
                Expanded(
                  child: AppTextField(
                    controller: _marksCtrl,
                    label: 'Total Marks',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.star_outline_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: _maxMbCtrl,
                    label: 'Max file (MB)',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.folder_outlined,
                  ),
                ),
              ]),
              const SizedBox(height: 16),

              // File types
              Text('Allowed File Types',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _typeOptions.map((t) {
                  final selected = _allowedTypes.contains(t);
                  return FilterChip(
                    label: Text(t.toUpperCase()),
                    selected: selected,
                    onSelected: (v) => setState(() {
                      if (v) _allowedTypes.add(t); else _allowedTypes.remove(t);
                    }),
                    selectedColor: AppColors.primary.withOpacity(0.15),
                    checkmarkColor: AppColors.primary,
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              PrimaryButton(
                label: 'Post Assignment',
                width: double.infinity,
                isLoading: _saving,
                onPressed: _create,
                icon: Icons.send_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
