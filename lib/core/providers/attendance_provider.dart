import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/attendance_models.dart';
import '../../services/attendance_service.dart';
import '../../services/geofence_service.dart';

class AttendanceSessionNotifier
    extends StateNotifier<AsyncValue<AttendanceSession?>> {
  AttendanceSessionNotifier() : super(const AsyncValue.data(null));

  Timer? _qrTimer;

  Future<void> start({
    required String timetableEntryId,
    required String facultyId,
    String? departmentId,
    String? courseId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final session = await AttendanceService.startSession(
        timetableEntryId: timetableEntryId,
        facultyId: facultyId,
        departmentId: departmentId,
        courseId: courseId,
      );
      state = AsyncValue.data(session);
      _startRotation(session.id);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _startRotation(String sessionId) {
    _qrTimer?.cancel();
    _qrTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await AttendanceService.rotateQrHash(sessionId);
      final current = state.valueOrNull;
      if (current != null) state = AsyncValue.data(current);
    });
  }

  Future<void> end() async {
    _qrTimer?.cancel();
    final session = state.valueOrNull;
    if (session == null) return;
    await AttendanceService.endSession(session.id);
    state = const AsyncValue.data(null);
  }

  void restore(AttendanceSession session) {
    state = AsyncValue.data(session);
    _startRotation(session.id);
  }

  @override
  void dispose() {
    _qrTimer?.cancel();
    super.dispose();
  }
}

final activeSessionProvider =
    StateNotifierProvider<AttendanceSessionNotifier, AsyncValue<AttendanceSession?>>(
  (ref) => AttendanceSessionNotifier(),
);

final sessionAttendeesProvider =
    StreamProvider.family<List<AttendanceRecord>, String>(
  (ref, sessionId) => AttendanceService.streamSessionAttendees(sessionId),
);

final facultyTodaySessionsProvider =
    FutureProvider.family<List<AttendanceSession>, String>(
  (ref, facultyId) => AttendanceService.getFacultyTodaySessions(facultyId),
);

final activeSessionsProvider =
    FutureProvider<List<AttendanceSession>>(
  (_) => AttendanceService.getActiveSessions(),
);

final studentAttendanceProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, studentId) => AttendanceService.getStudentAttendanceSummary(studentId),
);

final geofenceConfigProvider = FutureProvider<GeofenceConfig?>(
  (_) => GeofenceService.fetchActiveConfig(),
);

class GeofenceCheckNotifier extends StateNotifier<AsyncValue<GeofenceResult?>> {
  GeofenceCheckNotifier() : super(const AsyncValue.data(null));

  Future<void> check() async {
    state = const AsyncValue.loading();
    try {
      final result = await GeofenceService.checkPresence();
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void reset() => state = const AsyncValue.data(null);
}

final geofenceCheckProvider =
    StateNotifierProvider.autoDispose<GeofenceCheckNotifier, AsyncValue<GeofenceResult?>>(
  (ref) => GeofenceCheckNotifier(),
);
