import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/assignment_service.dart';
import '../../../shared/widgets/widgets.dart';

class StudentAssignmentsTab extends ConsumerStatefulWidget {
  const StudentAssignmentsTab({super.key});
  @override
  ConsumerState<StudentAssignmentsTab> createState() => _StudentAssignmentsTabState();
}

class _StudentAssignmentsTabState extends ConsumerState<StudentAssignmentsTab> {
  List<Assignment> _assignments = [];
  // Map of assignmentId -> submission (null means not submitted)
  final Map<String, AssignmentSubmission?> _submissions = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final assignments = await AssignmentService.getStudentAssignments(user.id);
      final subs = await Future.wait(
        assignments.map((a) => AssignmentService.getStudentSubmission(a.id, user.id)),
      );
      if (mounted) {
        setState(() {
          _assignments = assignments;
          for (var i = 0; i < assignments.length; i++) {
            _submissions[assignments[i].id] = subs[i];
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primary,
          child: _loading
              ? _buildShimmer()
              : _assignments.isEmpty
                  ? const EmptyState(
                      icon: Icons.assignment_outlined,
                      title: 'No assignments yet',
                      subtitle: 'Your faculty hasn\'t posted any assignments.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _assignments.length,
                      itemBuilder: (_, i) => _AssignmentCard(
                        assignment: _assignments[i],
                        submission: _submissions[_assignments[i].id],
                        onTap: () => _showDetail(_assignments[i]),
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(4, (_) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ShimmerBox(height: 100, radius: 16),
      )),
    );
  }

  void _showDetail(Assignment a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AssignmentDetailSheet(
        assignment: a,
        submission: _submissions[a.id],
        onSubmitted: _load,
      ),
    );
  }
}

// ── Assignment card ───────────────────────────────────────────────────────────

class _AssignmentCard extends StatelessWidget {
  final Assignment assignment;
  final AssignmentSubmission? submission;
  final VoidCallback onTap;

  const _AssignmentCard({
    required this.assignment,
    required this.submission,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final due = assignment.dueAt;
    final now = DateTime.now();
    final diff = due.difference(now);
    final isOverdue = diff.isNegative;
    final isGraded = submission?.isGraded ?? false;
    final isSubmitted = submission != null;

    Color statusColor;
    String statusLabel;
    if (isGraded) {
      statusColor = AppColors.success;
      statusLabel = 'Graded';
    } else if (isSubmitted) {
      statusColor = AppColors.info;
      statusLabel = 'Submitted';
    } else if (isOverdue) {
      statusColor = AppColors.danger;
      statusLabel = 'Overdue';
    } else {
      statusColor = AppColors.warning;
      statusLabel = 'Pending';
    }

    String countdownText;
    if (isOverdue) {
      countdownText = 'Due ${DateFormat('d MMM, hh:mm a').format(due)}';
    } else if (diff.inHours < 1) {
      countdownText = '${diff.inMinutes}m left';
    } else if (diff.inDays < 1) {
      countdownText = '${diff.inHours}h left';
    } else {
      countdownText = '${diff.inDays}d left';
    }

    Color timerColor = isOverdue
        ? AppColors.danger
        : diff.inHours < 24
            ? AppColors.warning
            : AppColors.success;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(assignment.title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: context.textPrimary)),
              ),
              _StatusBadge(label: statusLabel, color: statusColor),
            ]),
            const SizedBox(height: 6),
            if (assignment.course != null)
              Text(assignment.course!.name,
                  style: TextStyle(fontSize: 12, color: context.textSecondary)),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.schedule_rounded, size: 14, color: timerColor),
              const SizedBox(width: 4),
              Text(countdownText,
                  style: TextStyle(
                      fontSize: 12, color: timerColor, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${assignment.totalMarks} marks',
                  style: TextStyle(fontSize: 12, color: context.textMuted)),
            ]),
            if (isGraded) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                    '${submission!.marksObtained} / ${assignment.totalMarks} marks',
                    style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Detail / Submit sheet ─────────────────────────────────────────────────────

class _AssignmentDetailSheet extends ConsumerStatefulWidget {
  final Assignment assignment;
  final AssignmentSubmission? submission;
  final VoidCallback onSubmitted;

  const _AssignmentDetailSheet({
    required this.assignment,
    required this.submission,
    required this.onSubmitted,
  });

  @override
  ConsumerState<_AssignmentDetailSheet> createState() => _AssignmentDetailSheetState();
}

class _AssignmentDetailSheetState extends ConsumerState<_AssignmentDetailSheet> {
  bool _uploading = false;
  String? _error;
  String? _pickedFileName;
  Uint8List? _pickedBytes;

  Future<void> _pickFile() async {
    final a = widget.assignment;
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: _buildExtensions(a.allowedTypes),
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final sizeMb = (file.size) / (1024 * 1024);
    if (sizeMb > a.maxFileMb) {
      setState(() => _error = 'File exceeds max size of ${a.maxFileMb} MB');
      return;
    }
    setState(() {
      _pickedFileName = file.name;
      _pickedBytes = file.bytes;
      _error = null;
    });
  }

  List<String> _buildExtensions(List<String> types) {
    final exts = <String>[];
    for (final t in types) {
      switch (t) {
        case 'pdf':   exts.add('pdf'); break;
        case 'docx':  exts.addAll(['doc', 'docx']); break;
        case 'image': exts.addAll(['jpg', 'jpeg', 'png']); break;
        case 'zip':   exts.addAll(['zip', 'rar']); break;
      }
    }
    return exts.isEmpty ? ['*'] : exts;
  }

  Future<void> _submit() async {
    if (_pickedBytes == null || _pickedFileName == null) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() { _uploading = true; _error = null; });
    try {
      await AssignmentService.submitAssignment(
        assignmentId: widget.assignment.id,
        studentId: user.id,
        fileBytes: _pickedBytes!,
        fileName: _pickedFileName!,
        maxMb: widget.assignment.maxFileMb,
      );
      widget.onSubmitted();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { _uploading = false; _error = e.toString(); });
    }
  }

  Future<void> _openFile(String path) async {
    try {
      final url = await AssignmentService.getSignedUrl(path);
      await launchUrl(Uri.parse(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assignment;
    final sub = widget.submission;
    final isSubmitted = sub != null;
    final isGraded = sub?.isGraded ?? false;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      builder: (_, controller) => SingleChildScrollView(
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

            // Title + status
            Row(children: [
              Expanded(
                child: Text(a.title,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary)),
              ),
              if (isGraded)
                _StatusBadge(label: 'Graded', color: AppColors.success)
              else if (isSubmitted)
                _StatusBadge(label: 'Submitted', color: AppColors.info),
            ]),
            const SizedBox(height: 4),

            if (a.course != null)
              Text(a.course!.name,
                  style: TextStyle(fontSize: 13, color: context.textSecondary)),
            const SizedBox(height: 16),

            // Meta row
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _MetaChip(Icons.schedule_rounded,
                    'Due: ${DateFormat('d MMM yyyy, hh:mm a').format(a.dueAt)}',
                    a.isOverdue ? AppColors.danger : context.textSecondary),
                _MetaChip(Icons.star_outline_rounded,
                    '${a.totalMarks} marks', context.textSecondary),
                _MetaChip(Icons.insert_drive_file_outlined,
                    'Max ${a.maxFileMb} MB', context.textSecondary),
              ],
            ),
            const SizedBox(height: 16),

            if (a.description != null && a.description!.isNotEmpty) ...[
              Text('Description',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary)),
              const SizedBox(height: 6),
              Text(a.description!,
                  style: TextStyle(fontSize: 14, color: context.textPrimary)),
              const SizedBox(height: 16),
            ],

            // ── Question / instructions file ──────────────────────────────
            if (a.hasQuestionFile) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.description_outlined,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Question File',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                          Text(
                            a.questionFileName ?? 'Attachment',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ]),
                  ),
                  TextButton.icon(
                    onPressed: () => _openFile(a.questionFilePath!),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Download'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // Allowed types
            Text('Accepted formats',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: a.allowedTypes
                  .map((t) => Chip(
                        label: Text(t.toUpperCase()),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),

            // Graded result
            if (isGraded) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withOpacity(0.25)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Result',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success)),
                  const SizedBox(height: 8),
                  Text('${sub!.marksObtained} / ${a.totalMarks} marks',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.success)),
                  if (sub.feedback != null && sub.feedback!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Feedback: ${sub.feedback}',
                        style: TextStyle(fontSize: 13, color: context.textPrimary)),
                  ],
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // Existing submission file
            if (isSubmitted && sub!.fileUrl != null) ...[
              OutlinedButton.icon(
                onPressed: () => _openFile(sub!.fileUrl!),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(sub.fileName ?? 'Download submission'),
              ),
              const SizedBox(height: 16),
            ],

            // Submit area (only if not yet submitted + not overdue)
            if (!isSubmitted && !a.isOverdue) ...[
              if (_error != null) ...[
                ErrorContainer(message: _error!),
                const SizedBox(height: 12),
              ],
              if (_pickedFileName != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.attach_file_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_pickedFileName!,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: context.textPrimary, fontSize: 13)),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: context.textMuted),
                      onPressed: () =>
                          setState(() { _pickedFileName = null; _pickedBytes = null; }),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ]),
                ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploading ? null : _pickFile,
                    icon: const Icon(Icons.attach_file_rounded, size: 18),
                    label: Text(_pickedFileName == null ? 'Choose File' : 'Change File'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: 'Submit',
                    isLoading: _uploading,
                    onPressed: _pickedBytes != null ? _submit : null,
                    icon: Icons.upload_rounded,
                  ),
                ),
              ]),
            ],

            if (a.isOverdue && !isSubmitted)
              const InfoBanner(message: 'The deadline has passed. Submission is closed.'),
          ],
        ),
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _MetaChip(this.icon, this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 12, color: color)),
    ]);
  }
}
