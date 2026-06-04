import '../models/attendance_models.dart';
import '../models/models.dart';
import 'supabase_client.dart';
import 'qr_hash_service.dart';

class AttendanceService {
  AttendanceService._();

  // ── Sessions ────────────────────────────────────────────────

  /// Starts a new attendance session for a given timetable entry.
  /// Generates the first QR hash immediately.
  static Future<AttendanceSession> startSession({
    required String timetableEntryId,
    required String facultyId,
    String? departmentId,
    String? courseId,
  }) async {
    final now = DateTime.now();
    final hash = QrHashService.current(timetableEntryId);

    final res = await supabase.from('attendance_sessions').insert({
      'timetable_entry_id': timetableEntryId,
      'faculty_id': facultyId,
      'department_id': departmentId,
      'course_id': courseId,
      'session_date': now.toIso8601String().substring(0, 10),
      'status': 'active',
      'current_qr_hash': hash,
      'qr_updated_at': now.toIso8601String(),
    }).select('*, courses(id,name,code)').single();

    return AttendanceSession.fromJson(res);
  }

  /// Pushes a new QR hash to Supabase. Called every 5 seconds by the faculty.
  static Future<void> rotateQrHash(String sessionId) async {
    final hash = QrHashService.current(sessionId);
    await supabase.from('attendance_sessions').update({
      'current_qr_hash': hash,
      'qr_updated_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);
  }

  /// Ends an active session.
  static Future<void> endSession(String sessionId) async {
    await supabase.from('attendance_sessions').update({
      'status': 'ended',
      'ended_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);
  }

  /// Returns all sessions for today for a specific faculty.
  static Future<List<AttendanceSession>> getFacultyTodaySessions(
      String facultyId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final res = await supabase
        .from('attendance_sessions')
        .select('*, courses(id,name,code)')
        .eq('faculty_id', facultyId)
        .eq('session_date', today)
        .order('started_at', ascending: false);
    return (res as List).map((j) => AttendanceSession.fromJson(j)).toList();
  }

  /// Returns all active sessions (admin view).
  static Future<List<AttendanceSession>> getActiveSessions() async {
    final res = await supabase
        .from('attendance_sessions')
        .select('*, courses(id,name,code)')
        .eq('status', 'active')
        .order('started_at', ascending: false);
    return (res as List).map((j) => AttendanceSession.fromJson(j)).toList();
  }

  /// Returns a session by ID.
  static Future<AttendanceSession?> getSession(String sessionId) async {
    final res = await supabase
        .from('attendance_sessions')
        .select('*, courses(id,name,code)')
        .eq('id', sessionId)
        .maybeSingle();
    if (res == null) return null;
    return AttendanceSession.fromJson(res);
  }

  /// Paginated session history for admin.
  static Future<List<AttendanceSession>> getSessionHistory({
    String? facultyId,
    String? departmentId,
    int limit = 30,
    int offset = 0,
  }) async {
    var query = supabase
        .from('attendance_sessions')
        .select('*, courses(id,name,code)');

    if (facultyId != null) query = query.eq('faculty_id', facultyId);
    if (departmentId != null) query = query.eq('department_id', departmentId);

    final res = await query
        .order('started_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (res as List).map((j) => AttendanceSession.fromJson(j)).toList();
  }

  // ── Records ─────────────────────────────────────────────────

  /// Calls the atomic `mark_attendance` RPC on Supabase.
  /// Returns a map with `success: bool` and optionally `error: String`.
  static Future<Map<String, dynamic>> markAttendance({
    required String sessionId,
    required String studentId,
    required String qrHash,
    required double lat,
    required double lng,
    required bool isMocked,
  }) async {
    final res = await supabase.rpc('mark_attendance', params: {
      'p_session_id': sessionId,
      'p_student_id': studentId,
      'p_qr_hash': qrHash,
      'p_lat': lat,
      'p_lng': lng,
      'p_is_mocked': isMocked,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  /// Real-time stream of attendance records for a session (faculty QR screen).
  static Stream<List<AttendanceRecord>> streamSessionAttendees(
      String sessionId) {
    return supabase
        .from('attendance_records')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId)
        .order('marked_at')
        .map((rows) =>
            rows.map((j) => AttendanceRecord.fromJson(j)).toList());
  }

  /// All records for a session with student names (faculty / admin view).
  static Future<List<AttendanceRecord>> getSessionRecords(
      String sessionId) async {
    final res = await supabase
        .from('attendance_records')
        .select('*, profiles(id,full_name,roll_number)')
        .eq('session_id', sessionId)
        .order('marked_at');
    return (res as List).map((j) => AttendanceRecord.fromJson(j)).toList();
  }

  /// Student's own attendance history (student dashboard).
  static Future<List<Map<String, dynamic>>> getStudentAttendanceSummary(
      String studentId) async {
    // Returns sessions with their record for this student
    final res = await supabase
        .from('attendance_records')
        .select('''
          *,
          attendance_sessions(
            id, session_date, started_at, status,
            courses(id, name, code)
          )
        ''')
        .eq('student_id', studentId)
        .order('marked_at', ascending: false);
    return (res as List).cast<Map<String, dynamic>>();
  }

  // ── Admin Override ───────────────────────────────────────────

  /// Admin overrides a student's attendance record with a mandatory reason.
  static Future<void> adminOverride({
    required String recordId,
    required String sessionId,
    required String adminId,
    required String newStatus,
    required String reason,
  }) async {
    // Update the record
    await supabase.from('attendance_records').update({
      'status': newStatus,
      'is_override': true,
    }).eq('id', recordId);

    // Log the override
    await supabase.from('attendance_audit_logs').insert({
      'record_id': recordId,
      'session_id': sessionId,
      'admin_id': adminId,
      'action': 'override_$newStatus',
      'reason': reason,
    });
  }

  /// Admin terminates a session early.
  static Future<void> adminTerminateSession({
    required String sessionId,
    required String adminId,
    required String reason,
  }) async {
    await supabase.from('attendance_sessions').update({
      'status': 'cancelled',
      'ended_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);

    await supabase.from('attendance_audit_logs').insert({
      'session_id': sessionId,
      'admin_id': adminId,
      'action': 'terminate_session',
      'reason': reason,
    });
  }

  /// Audit logs for a session.
  static Future<List<AuditLog>> getAuditLogs(String sessionId) async {
    final res = await supabase
        .from('attendance_audit_logs')
        .select('*, profiles(id,full_name)')
        .eq('session_id', sessionId)
        .order('created_at', ascending: false);
    return (res as List).map((j) => AuditLog.fromJson(j)).toList();
  }
}
