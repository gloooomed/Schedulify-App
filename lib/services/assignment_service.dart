import 'dart:typed_data';
import '../models/models.dart';
import 'supabase_client.dart';

class AssignmentService {
  // ── Faculty: CRUD ──────────────────────────────────────────────────────────

  static Future<List<Assignment>> getFacultyAssignments(String facultyId) async {
    final res = await supabase
        .from('assignments')
        .select('*, courses(id,name,code)')
        .eq('faculty_id', facultyId)
        .order('due_at');
    return (res as List).map((j) => Assignment.fromJson(j)).toList();
  }

  static Future<void> createAssignment(Map<String, dynamic> data) async {
    await supabase.from('assignments').insert(data);
  }

  static Future<void> updateAssignment(String id, Map<String, dynamic> data) async {
    await supabase.from('assignments').update(data).eq('id', id);
  }

  static Future<void> deleteAssignment(String id) async {
    await supabase.from('assignments').delete().eq('id', id);
  }

  // ── Faculty: Grading ───────────────────────────────────────────────────────

  static Future<List<AssignmentSubmission>> getSubmissionsForAssignment(String assignmentId) async {
    final res = await supabase
        .from('assignment_submissions')
        .select('*, profiles(id,full_name,roll_number)')
        .eq('assignment_id', assignmentId)
        .order('submitted_at');
    return (res as List).map((j) => AssignmentSubmission.fromJson(j)).toList();
  }

  static Future<void> gradeSubmission(String submissionId, int marks, String? feedback) async {
    await supabase.from('assignment_submissions').update({
      'marks_obtained': marks,
      'feedback': feedback,
      'graded_at': DateTime.now().toIso8601String(),
      'graded_by': supabase.auth.currentUser!.id,
    }).eq('id', submissionId);
  }

  // ── Student: Read + Submit ─────────────────────────────────────────────────

  static Future<List<Assignment>> getStudentAssignments(String studentId) async {
    final enrollments = await supabase
        .from('student_enrollments')
        .select('course_id')
        .eq('student_id', studentId)
        .eq('status', 'active');
    final courseIds = (enrollments as List).map((e) => e['course_id'] as String).toList();
    if (courseIds.isEmpty) return [];
    final res = await supabase
        .from('assignments')
        .select('*, courses(id,name,code)')
        .inFilter('course_id', courseIds)
        .order('due_at');
    return (res as List).map((j) => Assignment.fromJson(j)).toList();
  }

  static Future<AssignmentSubmission?> getStudentSubmission(
      String assignmentId, String studentId) async {
    final res = await supabase
        .from('assignment_submissions')
        .select()
        .eq('assignment_id', assignmentId)
        .eq('student_id', studentId)
        .maybeSingle();
    if (res == null) return null;
    return AssignmentSubmission.fromJson(res as Map<String, dynamic>);
  }

  static Future<void> submitAssignment({
    required String assignmentId,
    required String studentId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final path = 'submissions/$assignmentId/$studentId/$fileName';
    await supabase.storage.from('assignments').uploadBinary(
      path,
      fileBytes,
      fileOptions: const FileOptions(upsert: true),
    );
    await supabase.from('assignment_submissions').upsert({
      'assignment_id': assignmentId,
      'student_id': studentId,
      'file_url': path,
      'file_name': fileName,
      'submitted_at': DateTime.now().toIso8601String(),
    }, onConflict: 'assignment_id,student_id');
  }

  // ── Signed URL ─────────────────────────────────────────────────────────────

  static Future<String> getSignedUrl(String storagePath) async {
    return supabase.storage
        .from('assignments')
        .createSignedUrl(storagePath, 3600);
  }

  // ── Admin ──────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getComplianceStats() async {
    final res = await supabase.rpc('get_assignment_compliance');
    return (res as List).cast<Map<String, dynamic>>();
  }

  static Future<List<Assignment>> getAllAssignments() async {
    final res = await supabase
        .from('assignments')
        .select('*, courses(id,name,code,departments(id,name))')
        .order('created_at', ascending: false);
    return (res as List).map((j) => Assignment.fromJson(j)).toList();
  }
}
