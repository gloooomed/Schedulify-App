
class GeofenceConfig {
  final String id;
  final String name;
  final List<GeofencePoint> polygonPoints;
  final bool isActive;
  final DateTime updatedAt;

  const GeofenceConfig({
    required this.id,
    required this.name,
    required this.polygonPoints,
    required this.isActive,
    required this.updatedAt,
  });

  factory GeofenceConfig.fromJson(Map<String, dynamic> j) => GeofenceConfig(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Campus Geofence',
        polygonPoints: (j['polygon_points'] as List)
            .map((p) => GeofencePoint.fromJson(p as Map<String, dynamic>))
            .toList(),
        isActive: j['is_active'] as bool? ?? true,
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'polygon_points': polygonPoints.map((p) => p.toJson()).toList(),
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      };
}

class GeofencePoint {
  final double lat;
  final double lng;

  const GeofencePoint({required this.lat, required this.lng});

  factory GeofencePoint.fromJson(Map<String, dynamic> j) => GeofencePoint(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

class AttendanceSession {
  final String id;
  final String timetableEntryId;
  final String facultyId;
  final String? departmentId;
  final String? courseId;
  final DateTime sessionDate;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String status; // active | ended | cancelled
  final String? currentQrHash;
  final DateTime? qrUpdatedAt;

  final String? courseName;
  final String? courseCode;

  const AttendanceSession({
    required this.id,
    required this.timetableEntryId,
    required this.facultyId,
    this.departmentId,
    this.courseId,
    required this.sessionDate,
    required this.startedAt,
    this.endedAt,
    required this.status,
    this.currentQrHash,
    this.qrUpdatedAt,
    this.courseName,
    this.courseCode,
  });

  bool get isActive => status == 'active';

  factory AttendanceSession.fromJson(Map<String, dynamic> j) {
    String? courseName;
    String? courseCode;
    if (j['courses'] != null) {
      final c = j['courses'] as Map<String, dynamic>;
      courseName = c['name'] as String?;
      courseCode = c['code'] as String?;
    }
    return AttendanceSession(
      id: j['id'] as String,
      timetableEntryId: j['timetable_entry_id'] as String,
      facultyId: j['faculty_id'] as String,
      departmentId: j['department_id'] as String?,
      courseId: j['course_id'] as String?,
      sessionDate: DateTime.parse(j['session_date'] as String),
      startedAt: DateTime.parse(j['started_at'] as String),
      endedAt: j['ended_at'] != null ? DateTime.parse(j['ended_at'] as String) : null,
      status: j['status'] as String? ?? 'active',
      currentQrHash: j['current_qr_hash'] as String?,
      qrUpdatedAt: j['qr_updated_at'] != null
          ? DateTime.parse(j['qr_updated_at'] as String)
          : null,
      courseName: courseName,
      courseCode: courseCode,
    );
  }
}

class AttendanceRecord {
  final String id;
  final String sessionId;
  final String studentId;
  final DateTime markedAt;
  final String status; // present | absent | late | excused
  final Map<String, dynamic>? locationData;
  final String? qrHashUsed;
  final bool isOverride;

  final String? studentName;
  final String? rollNumber;

  const AttendanceRecord({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.markedAt,
    required this.status,
    this.locationData,
    this.qrHashUsed,
    required this.isOverride,
    this.studentName,
    this.rollNumber,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) {
    String? studentName;
    String? rollNumber;
    if (j['profiles'] != null) {
      final p = j['profiles'] as Map<String, dynamic>;
      studentName = p['full_name'] as String?;
      rollNumber = p['roll_number'] as String?;
    }
    return AttendanceRecord(
      id: j['id'] as String,
      sessionId: j['session_id'] as String,
      studentId: j['student_id'] as String,
      markedAt: DateTime.parse(j['marked_at'] as String),
      status: j['status'] as String? ?? 'present',
      locationData: j['location_data'] as Map<String, dynamic>?,
      qrHashUsed: j['qr_hash_used'] as String?,
      isOverride: j['is_override'] as bool? ?? false,
      studentName: studentName,
      rollNumber: rollNumber,
    );
  }
}

class AuditLog {
  final String id;
  final String? recordId;
  final String? sessionId;
  final String adminId;
  final String action;
  final String reason;
  final DateTime createdAt;

  final String? adminName;

  const AuditLog({
    required this.id,
    this.recordId,
    this.sessionId,
    required this.adminId,
    required this.action,
    required this.reason,
    required this.createdAt,
    this.adminName,
  });

  factory AuditLog.fromJson(Map<String, dynamic> j) {
    String? adminName;
    if (j['profiles'] != null) {
      adminName = (j['profiles'] as Map<String, dynamic>)['full_name'] as String?;
    }
    return AuditLog(
      id: j['id'] as String,
      recordId: j['record_id'] as String?,
      sessionId: j['session_id'] as String?,
      adminId: j['admin_id'] as String,
      action: j['action'] as String,
      reason: j['reason'] as String,
      createdAt: DateTime.parse(j['created_at'] as String),
      adminName: adminName,
    );
  }
}

class GeofenceResult {
  final bool isInside;
  final bool isMocked;
  final double lat;
  final double lng;
  final double accuracy;

  const GeofenceResult({
    required this.isInside,
    required this.isMocked,
    required this.lat,
    required this.lng,
    required this.accuracy,
  });
}
