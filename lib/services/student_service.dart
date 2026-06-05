import '../models/models.dart';
import 'supabase_client.dart';

extension DbServiceStudentCourses on Object {
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
}
