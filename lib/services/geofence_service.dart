import 'package:geolocator/geolocator.dart';
import 'package:maps_toolkit/maps_toolkit.dart';
import '../models/attendance_models.dart';
import 'supabase_client.dart';

/// Handles campus geofence loading and GPS-based containment checks.
class GeofenceService {
  GeofenceService._();

  // Cached active polygon (refreshed on each app session / tab open)
  static List<GeofencePoint>? _cachedPolygon;

  /// Extra GPS buffer in metres — accounts for indoor GPS drift.
  /// A student this many metres outside the polygon boundary still passes.
  static const double _bufferMetres = 60.0;

  // ── Polygon Management ──────────────────────────────────────

  /// Fetches the active geofence polygon from Supabase and caches it.
  /// Returns null if no geofence has been configured yet.
  static Future<GeofenceConfig?> fetchActiveConfig() async {
    try {
      final res = await supabase
          .from('geofence_config')
          .select()
          .eq('is_active', true)
          .maybeSingle();
      if (res == null) return null;
      final config = GeofenceConfig.fromJson(res);
      _cachedPolygon = config.polygonPoints;
      return config;
    } catch (_) {
      return null;
    }
  }

  /// Saves (upserts) a new active geofence polygon, deactivating any previous one.
  static Future<void> savePolygon({
    required String adminId,
    required String name,
    required List<GeofencePoint> points,
  }) async {
    // Deactivate existing
    await supabase
        .from('geofence_config')
        .update({'is_active': false})
        .eq('is_active', true);

    // Insert new active config
    await supabase.from('geofence_config').insert({
      'name': name,
      'polygon_points': points.map((p) => p.toJson()).toList(),
      'is_active': true,
      'created_by': adminId,
      'updated_at': DateTime.now().toIso8601String(),
    });

    _cachedPolygon = points;
  }

  // ── Location & Containment Check ────────────────────────────

  /// Requests permission, gets current position, and checks if it's inside
  /// the active geofence polygon (with a [_bufferMetres] tolerance for GPS drift).
  ///
  /// **If no geofence has been configured by an admin, the check is bypassed
  /// and [GeofenceResult.isInside] is true — so the system fails open rather
  /// than locking everyone out.**
  static Future<GeofenceResult?> checkPresence() async {
    // 1. Permission
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      return null; // caller shows "grant permission" prompt
    }

    // 2. Get position with high accuracy
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 20),
      ),
    );

    // 3. Ensure polygon is loaded
    if (_cachedPolygon == null) await fetchActiveConfig();
    final polygon = _cachedPolygon;

    // 4. If no polygon configured → bypass (fail open)
    if (polygon == null || polygon.length < 3) {
      return GeofenceResult(
        isInside: true,  // no fence = open campus
        isMocked: pos.isMocked,
        lat: pos.latitude,
        lng: pos.longitude,
        accuracy: pos.accuracy,
      );
    }

    final latLngs = polygon.map((p) => LatLng(p.lat, p.lng)).toList();
    final deviceLatLng = LatLng(pos.latitude, pos.longitude);

    // 5. Primary check: point is strictly inside the polygon
    bool isInside = PolygonUtil.containsLocation(deviceLatLng, latLngs, true);

    // 6. Buffer check: even if outside, accept if within _bufferMetres of any edge
    //    This accounts for indoor GPS drift of 10–50 m on most phones.
    if (!isInside) {
      final distToEdge = _minDistanceToPolygonEdge(deviceLatLng, latLngs);
      if (distToEdge <= _bufferMetres) {
        isInside = true;
      }
    }

    return GeofenceResult(
      isInside: isInside,
      isMocked: pos.isMocked,
      lat: pos.latitude,
      lng: pos.longitude,
      accuracy: pos.accuracy,
    );
  }

  /// Returns the minimum distance (metres) from [point] to any edge of [polygon].
  static double _minDistanceToPolygonEdge(
      LatLng point, List<LatLng> polygon) {
    double minDist = double.infinity;
    final n = polygon.length;
    for (int i = 0; i < n; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % n];
      final d = PolygonUtil.distanceToLine(point, a, b).toDouble();
      if (d < minDist) minDist = d;
    }
    return minDist;
  }

  /// Whether a geofence has been configured by the admin.
  static bool get isConfigured =>
      _cachedPolygon != null && _cachedPolygon!.length >= 3;

  /// Clears the local cache (call on logout or config change).
  static void clearCache() => _cachedPolygon = null;
}
