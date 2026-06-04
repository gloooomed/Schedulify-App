import 'package:geolocator/geolocator.dart';
import 'package:maps_toolkit/maps_toolkit.dart';
import '../models/attendance_models.dart';
import 'supabase_client.dart';

/// Handles campus geofence loading and GPS-based containment checks.
class GeofenceService {
  GeofenceService._();

  // Cached active polygon (refreshed on each app session / tab open)
  static List<GeofencePoint>? _cachedPolygon;

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
  /// the active geofence polygon.
  /// Returns a [GeofenceResult] with all details needed for the RPC call.
  static Future<GeofenceResult?> checkPresence() async {
    // 1. Permission
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      return null; // caller should show a "grant permission" prompt
    }

    // 2. Get position
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );

    // 3. Ensure polygon is loaded
    if (_cachedPolygon == null) await fetchActiveConfig();
    final polygon = _cachedPolygon;

    bool isInside = false;
    if (polygon != null && polygon.length >= 3) {
      final latLngs =
          polygon.map((p) => LatLng(p.lat, p.lng)).toList();
      isInside = PolygonUtil.containsLocation(
        LatLng(pos.latitude, pos.longitude),
        latLngs,
        true, // geodesic
      );
    }

    return GeofenceResult(
      isInside: isInside,
      isMocked: pos.isMocked,
      lat: pos.latitude,
      lng: pos.longitude,
      accuracy: pos.accuracy,
    );
  }

  /// Whether a geofence has been configured by the admin.
  static bool get isConfigured => _cachedPolygon != null && _cachedPolygon!.length >= 3;

  /// Clears the local cache (call on logout or config change).
  static void clearCache() => _cachedPolygon = null;
}
