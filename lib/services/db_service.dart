import '../models/models.dart';
import 'supabase_client.dart';

class DbService {
  // ── Courses ────────────────────────────────────────────────────────────────
  static Future<List<Course>> getCourses() async {
    final res = await supabase
        .from('courses')
        .select('*, departments(id,name,code)')
        .order('name');
    return (res as List).map((j) => Course.fromJson(j)).toList();
  }

  static Future<void> createCourse(Map<String, dynamic> data) async {
    await supabase.from('courses').insert(data);
  }

  static Future<void> updateCourse(String id, Map<String, dynamic> data) async {
    await supabase.from('courses').update(data).eq('id', id);
  }

  static Future<void> deleteCourse(String id) async {
    await supabase.from('courses').delete().eq('id', id);
  }

  // ── Departments ────────────────────────────────────────────────────────────
  static Future<List<Department>> getDepartments() async {
    final res = await supabase
        .from('departments')
        .select('*, profiles(id,full_name)')
        .order('name');
    return (res as List).map((j) => Department.fromJson(j)).toList();
  }

  static Future<void> createDepartment(Map<String, dynamic> data) async {
    await supabase.from('departments').insert(data);
  }

  static Future<void> updateDepartment(String id, Map<String, dynamic> data) async {
    await supabase.from('departments').update(data).eq('id', id);
  }

  static Future<void> deleteDepartment(String id) async {
    await supabase.from('departments').delete().eq('id', id);
  }

  // ── Classrooms ─────────────────────────────────────────────────────────────
  static Future<List<Classroom>> getClassrooms() async {
    final res = await supabase.from('classrooms').select().order('name');
    return (res as List).map((j) => Classroom.fromJson(j)).toList();
  }

  static Future<void> createClassroom(Map<String, dynamic> data) async {
    await supabase.from('classrooms').insert(data);
  }

  static Future<void> updateClassroom(String id, Map<String, dynamic> data) async {
    await supabase.from('classrooms').update(data).eq('id', id);
  }

  static Future<void> deleteClassroom(String id) async {
    await supabase.from('classrooms').delete().eq('id', id);
  }

  // ── Users (Faculty / Students) ─────────────────────────────────────────────
  static Future<List<Profile>> getFacultyList() async {
    final res = await supabase
        .from('profiles')
        .select()
        .eq('role', 'faculty')
        .eq('is_active', true)
        .order('full_name');
    return (res as List).map((j) => Profile.fromJson(j)).toList();
  }

  static Future<List<Profile>> getAllUsers() async {
    final res = await supabase
        .from('profiles')
        .select()
        .inFilter('role', ['faculty', 'student'])
        .order('full_name');
    return (res as List).map((j) => Profile.fromJson(j)).toList();
  }

  static Future<void> updateProfile(String id, Map<String, dynamic> data) async {
    await supabase.from('profiles').update(data).eq('id', id);
  }

  static Future<void> toggleUserActive(String id, bool isActive) async {
    await supabase.from('profiles').update({'is_active': isActive}).eq('id', id);
  }

  // ── Timetables ─────────────────────────────────────────────────────────────
  static Future<List<Timetable>> getTimetables() async {
    final res = await supabase
        .from('timetables')
        .select('*, departments(id,name,code)')
        .order('created_at', ascending: false);
    return (res as List).map((j) => Timetable.fromJson(j)).toList();
  }

  static Future<void> createTimetable(Map<String, dynamic> data) async {
    await supabase.from('timetables').insert(data);
  }

  static Future<void> updateTimetable(String id, Map<String, dynamic> data) async {
    await supabase.from('timetables').update(data).eq('id', id);
  }

  static Future<void> publishTimetable(String id) async {
    // Deactivate all others first
    await supabase.from('timetables').update({'is_active': false, 'status': 'archived'});
    await supabase.from('timetables').update({
      'status': 'published',
      'is_active': true,
    }).eq('id', id);
  }

  static Future<void> archiveTimetable(String id) async {
    await supabase.from('timetables').update({
      'status': 'archived',
      'is_active': false,
    }).eq('id', id);
  }

  static Future<void> deleteTimetable(String id) async {
    await supabase.from('timetables').delete().eq('id', id);
  }

  // ── Timetable Entries ──────────────────────────────────────────────────────
  static Future<List<TimetableEntry>> getActiveTimetableEntries() async {
    final res = await supabase
        .from('timetable_entries')
        .select('''
          *,
          courses(id,name,code,course_type),
          profiles(id,full_name,department_id),
          classrooms(id,name,building),
          timetables!inner(is_active)
        ''')
        .eq('timetables.is_active', true);
    return (res as List).map((j) => TimetableEntry.fromJson(j)).toList();
  }

  static Future<List<TimetableEntry>> getFacultySchedule(String facultyId) async {
    final res = await supabase
        .from('timetable_entries')
        .select('''
          *,
          courses(id,name,code,course_type),
          classrooms(id,name,building),
          timetables!inner(is_active)
        ''')
        .eq('faculty_id', facultyId)
        .eq('timetables.is_active', true);
    return (res as List).map((j) => TimetableEntry.fromJson(j)).toList();
  }

  static Future<List<TimetableEntry>> getStudentSchedule(String studentId) async {
    final enrollments = await supabase
        .from('student_enrollments')
        .select('course_id')
        .eq('student_id', studentId)
        .eq('status', 'active');
    final courseIds = (enrollments as List).map((e) => e['course_id'] as String).toList();
    if (courseIds.isEmpty) return [];
    final res = await supabase
        .from('timetable_entries')
        .select('''
          *,
          courses(id,name,code,course_type),
          profiles(id,full_name),
          classrooms(id,name,building),
          timetables!inner(is_active)
        ''')
        .inFilter('course_id', courseIds)
        .eq('timetables.is_active', true);
    return (res as List).map((j) => TimetableEntry.fromJson(j)).toList();
  }

  static Future<void> insertTimetableEntries(List<Map<String, dynamic>> entries) async {
    await supabase.from('timetable_entries').insert(entries);
  }

  // ── Student Courses ────────────────────────────────────────────────────────
  static Future<List<Course>> getStudentCourses(String studentId) async {
    final res = await supabase
        .from('student_enrollments')
        .select('courses(*, departments(id,name,code))')
        .eq('student_id', studentId)
        .eq('status', 'active');
    return (res as List)
        .map((e) => Course.fromJson(e['courses'] as Map<String, dynamic>))
        .toList();
  }

  // ── Stats ──────────────────────────────────────────────────────────────────
  static Future<Map<String, int>> getDashboardStats() async {
    final futures = await Future.wait([
      supabase.from('departments').select('id'),
      supabase.from('courses').select('id'),
      supabase.from('classrooms').select('id'),
      supabase.from('profiles').select('id').inFilter('role', ['faculty', 'student']),
      supabase.from('timetables').select('id').eq('status', 'published'),
    ]);
    return {
      'departments': (futures[0] as List).length,
      'courses': (futures[1] as List).length,
      'classrooms': (futures[2] as List).length,
      'users': (futures[3] as List).length,
      'activeTimetables': (futures[4] as List).length,
    };
  }
}
