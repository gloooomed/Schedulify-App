import 'package:geolocator/geolocator.dart';
import 'package:maps_toolkit/maps_toolkit.dart';
import '../models/attendance_models.dart';
import 'supabase_client.dart';

class GeofenceService {
  GeofenceService._();

  static List<GeofencePoint>? _cachedPolygon;
  static const double _maxBufferMetres = 20.0;

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

  static Future<void> savePolygon({
    required String adminId,
    required String name,
    required List<GeofencePoint> points,
  }) async {
    await supabase
        .from('geofence_config')
        .update({'is_active': false})
        .eq('is_active', true);

    await supabase.from('geofence_config').insert({
      'name': name,
      'polygon_points': points.map((p) => p.toJson()).toList(),
      'is_active': true,
      'created_by': adminId,
      'updated_at': DateTime.now().toIso8601String(),
    });

    _cachedPolygon = points;
  }

  static Future<GeofenceResult?> checkPresence() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      return null;
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 20),
      ),
    );

    if (_cachedPolygon == null) await fetchActiveConfig();
    final polygon = _cachedPolygon;

    if (polygon == null || polygon.length < 3) {
      return GeofenceResult(
        isInside: false,
        isMocked: pos.isMocked,
        lat: pos.latitude,
        lng: pos.longitude,
        accuracy: pos.accuracy,
      );
    }

    final latLngs = polygon.map((p) => LatLng(p.lat, p.lng)).toList();
    final deviceLatLng = LatLng(pos.latitude, pos.longitude);

    bool isInside = PolygonUtil.containsLocation(deviceLatLng, latLngs, true);

    if (!isInside) {
      final buffer = pos.accuracy.clamp(0.0, _maxBufferMetres);
      if (_minDistanceToPolygonEdge(deviceLatLng, latLngs) <= buffer) {
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

  static double _minDistanceToPolygonEdge(LatLng point, List<LatLng> polygon) {
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

  static bool get isConfigured =>
      _cachedPolygon != null && _cachedPolygon!.length >= 3;

  static void clearCache() => _cachedPolygon = null;
}
