import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/db_service.dart';
import '../../../services/groq_service.dart';
import '../../../shared/widgets/widgets.dart';

class UploadTab extends StatefulWidget {
  const UploadTab({super.key});
  @override
  State<UploadTab> createState() => _UploadTabState();
}

class _UploadTabState extends State<UploadTab> {
  int _step = 0; // 0=upload, 1=preview, 2=save
  String _rawText = '';
  List<Map<String, dynamic>> _parsed = [];
  String? _conflicts;
  bool _isLoading = false;
  String? _error;
  List<Timetable> _timetables = [];
  String? _selectedTimetableId;

  final _groqKey = const String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
  final _pasteController = TextEditingController();

  @override
  void initState() { super.initState(); _loadTimetables(); }

  Future<void> _loadTimetables() async {
    try {
      final all = await DbService.getTimetables();
      setState(() { _timetables = all.where((t) => t.status == 'draft').toList(); });
    } catch (_) {}
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['csv', 'txt'],
        withData: true);
    if (result == null) return;
    final bytes = result.files.first.bytes;
    if (bytes != null) {
      setState(() { _rawText = String.fromCharCodes(bytes); _pasteController.text = _rawText; });
    }
  }

  Future<void> _parse() async {
    final text = _pasteController.text.trim();
    if (text.isEmpty) { setState(() => _error = 'Paste or upload schedule data first.'); return; }
    if (_groqKey.isEmpty) { setState(() => _error = 'GROQ_API_KEY not configured.'); return; }
    setState(() { _isLoading = true; _error = null; _rawText = text; });
    try {
      final groq = GroqService(_groqKey);
      final entries = await groq.parseSchedule(text);
      final conflicts = await groq.detectConflicts(entries);
      setState(() {
        _parsed = entries; _conflicts = conflicts;
        _isLoading = false; _step = 1;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _save() async {
    if (_selectedTimetableId == null) { setState(() => _error = 'Select a timetable first.'); return; }
    setState(() { _isLoading = true; _error = null; });
    try {
      final courses = await DbService.getCourses();
      final classrooms = await DbService.getClassrooms();
      final faculty = await DbService.getFacultyList();

      final entries = _parsed.map((e) {
        final course = courses.firstWhere(
            (c) => c.name.toLowerCase().contains((e['courseName'] ?? '').toString().toLowerCase())
                || c.code.toLowerCase() == (e['courseCode'] ?? '').toString().toLowerCase(),
            orElse: () => courses.first);
        final room = classrooms.firstWhere(
            (r) => r.name.toLowerCase().contains((e['roomName'] ?? '').toString().toLowerCase()),
            orElse: () => classrooms.first);
        final fac = faculty.firstWhere(
            (f) => f.fullName.toLowerCase().contains((e['facultyName'] ?? '').toString().toLowerCase()),
            orElse: () => faculty.first);
        return {
          'timetable_id': _selectedTimetableId,
          'course_id': course.id,
          'classroom_id': room.id,
          'faculty_id': fac.id,
          'day_of_week': e['dayOfWeek'] ?? 1,
          'start_time': e['startTime'] ?? '09:00',
          'end_time': e['endTime'] ?? '10:00',
          'session_type': e['sessionType'] ?? 'lecture',
          'student_group': e['studentGroup'],
        };
      }).toList();

      await DbService.insertTimetableEntries(entries);
      setState(() { _isLoading = false; _step = 2; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const PageHeader(title: 'AI Schedule Upload',
            subtitle: 'Upload CSV/text — AI parses & saves entries'),
        const SizedBox(height: 24),
        Row(children: List.generate(3, (i) {
          final active = i <= _step;
          return Expanded(child: Row(children: [
            if (i > 0) Expanded(child: Container(height: 1,
                color: active ? AppColors.primary : Theme.of(context).dividerColor)),
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? AppColors.primary : Theme.of(context).colorScheme.surface,
                border: Border.all(color: active ? AppColors.primary : Theme.of(context).dividerColor),
              ),
              child: Center(child: i < _step
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : Text('${i+1}', style: TextStyle(color: active ? Colors.white : AppColors.textMuted,
                      fontSize: 12, fontWeight: FontWeight.w700))),
            ),
            if (i < 2) Expanded(child: Container(height: 1,
                color: i < _step ? AppColors.primary : Theme.of(context).dividerColor)),
          ]));
        })),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: ['Upload', 'Preview', 'Done']
              .map((l) => Text(l, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)))).toList()),
        ),
        const SizedBox(height: 20),
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.danger.withOpacity(0.3))),
            child: Text(_error!, style: TextStyle(color: AppColors.danger)),
          ),
        if (_step == 0) _uploadStep(),
        if (_step == 1) _previewStep(),
        if (_step == 2) _doneStep(),
      ],
    );
  }

  Widget _uploadStep() => GlassCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Step 1: Upload Schedule Data',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: _pickFile,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor, style: BorderStyle.solid),
          ),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.upload_file_rounded, color: AppColors.primary, size: 36),
            SizedBox(height: 10),
            Text('Tap to upload CSV/TXT file',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 14)),
          ])),
        ),
      ),
      const SizedBox(height: 16),
      Text('Or paste schedule text:',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 13)),
      const SizedBox(height: 8),
      TextFormField(
        controller: _pasteController,
        maxLines: 8,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Monday 9:00-10:00 Mathematics (MATH101) - Dr. Smith - Room LH-101',
          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38), fontSize: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).dividerColor)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).dividerColor)),
          filled: true, fillColor: Theme.of(context).colorScheme.surface,
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
      const SizedBox(height: 20),
      PrimaryButton(label: 'Parse with AI', icon: Icons.auto_awesome_rounded,
          width: double.infinity, isLoading: _isLoading, onPressed: _parse),
    ]),
  );

  Widget _previewStep() => Column(children: [
    if (_conflicts != null && _conflicts!.isNotEmpty)
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
            SizedBox(width: 8),
            Text('Conflicts Detected', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          Text(_conflicts!, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 13)),
        ]),
      ),
    GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${_parsed.length} entries parsed',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 16),
        ..._parsed.take(5).map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Center(child: Text('${e['dayOfWeek'] ?? 0}',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${e['courseName']} (${e['courseCode']})',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface, fontSize: 13)),
              Text('${e['startTime']} - ${e['endTime']} · ${e['facultyName']} · ${e['roomName']}',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
            ])),
          ]),
        )),
        if (_parsed.length > 5)
          Text('...and ${_parsed.length - 5} more entries',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38))),
        const SizedBox(height: 20),
        if (_timetables.isEmpty)
          const Text('No draft timetables found. Create one first.',
              style: TextStyle(color: AppColors.danger))
        else ...[
          DropdownButtonFormField<String>(
            value: _selectedTimetableId, dropdownColor: Theme.of(context).colorScheme.surface,
            decoration: InputDecoration(labelText: 'Save to Timetable',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                filled: true, fillColor: Theme.of(context).colorScheme.surface),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            items: _timetables.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
            onChanged: (v) => setState(() => _selectedTimetableId = v),
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Save Entries', icon: Icons.save_rounded,
              width: double.infinity, isLoading: _isLoading, onPressed: _save),
        ],
      ]),
    ),
  ]);

  Widget _doneStep() => GlassCard(
    child: Column(children: [
      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 56),
      const SizedBox(height: 16),
      Text('Entries Saved!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface)),
      const SizedBox(height: 8),
      Text('${_parsed.length} timetable entries were saved successfully.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)), textAlign: TextAlign.center),
      const SizedBox(height: 24),
      PrimaryButton(label: 'Upload Another', icon: Icons.upload_rounded,
          width: double.infinity,
          onPressed: () => setState(() { _step = 0; _parsed = []; _conflicts = null; _pasteController.clear(); })),
    ]),
  );
}

