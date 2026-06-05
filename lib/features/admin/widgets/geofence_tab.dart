import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/attendance_models.dart';
import '../../../services/geofence_service.dart';
import '../../../shared/widgets/widgets.dart';

class GeofenceTab extends ConsumerStatefulWidget {
  const GeofenceTab({super.key});

  @override
  ConsumerState<GeofenceTab> createState() => _GeofenceTabState();
}

class _GeofenceTabState extends ConsumerState<GeofenceTab> {
  final MapController _mapController = MapController();
  final _nameController = TextEditingController(text: 'Campus Geofence');

  List<LatLng> _points = [];
  bool _saving = false;
  bool _locating = false;
  LatLng _center = const LatLng(22.5726, 88.3639); // Kolkata default
  GeofenceConfig? _existingConfig;

  @override
  void initState() {
    super.initState();
    _loadExisting();
    _goToCurrentLocation();
  }

  Future<void> _loadExisting() async {
    final config = await GeofenceService.fetchActiveConfig();
    if (!mounted || config == null) return;
    setState(() {
      _existingConfig = config;
      _nameController.text = config.name;
      _points = config.polygonPoints
          .map((p) => LatLng(p.lat, p.lng))
          .toList();
      if (_points.isNotEmpty) _center = _points.first;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_points.isNotEmpty) _mapController.move(_center, 18);
    });
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));
      setState(() => _center = LatLng(pos.latitude, pos.longitude));
      _mapController.move(_center, 18);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onTap(TapPosition _, LatLng point) {
    setState(() => _points.add(point));
  }

  void _removePoint(int idx) {
    setState(() => _points.removeAt(idx));
  }

  Future<void> _save() async {
    if (_points.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add at least 3 points to form a polygon')));
      return;
    }
    setState(() => _saving = true);
    try {
      final user = ref.read(currentUserProvider);
      await GeofenceService.savePolygon(
        adminId: user!.id,
        name: _nameController.text.trim().isEmpty
            ? 'Campus Geofence'
            : _nameController.text.trim(),
        points: _points
            .map((p) => GeofencePoint(lat: p.latitude, lng: p.longitude))
            .toList(),
      );
      ref.invalidate(geofenceConfigProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Geofence saved successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isClosed = _points.length >= 3;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PageHeader(
          title: 'Campus Geofence',
          subtitle: 'Tap the map to mark your building boundary',
        ),
        const SizedBox(height: 16),

        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.info_outline_rounded, color: AppColors.info, size: 18),
                const SizedBox(width: 8),
                Text('How to set up',
                    style: TextStyle(fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ]),
              const SizedBox(height: 12),
              _Step('1', 'Tap the map to drop points around your building corners'),
              _Step('2', 'Add at least 3 points — more points = more accurate boundary'),
              _Step('3', 'The green polygon shows the attendance zone'),
              _Step('4', 'Students outside this zone cannot check in'),
              _Step('5', 'Tap Save when the boundary looks correct'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        AppTextField(
          controller: _nameController,
          label: 'Geofence Name',
          prefixIcon: Icons.place_rounded,
        ),
        const SizedBox(height: 16),

        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 380,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 17,
                    onTap: _onTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.schedulify.app',
                    ),
                    if (isClosed)
                      PolygonLayer(polygons: [
                        Polygon(
                          points: _points,
                          color: AppColors.primary.withOpacity(0.2),
                          borderColor: AppColors.primary,
                          borderStrokeWidth: 2,
                        ),
                      ]),
                    MarkerLayer(
                      markers: _points.asMap().entries.map((e) {
                        return Marker(
                          point: e.value,
                          width: 28,
                          height: 28,
                          child: GestureDetector(
                            onLongPress: () => _removePoint(e.key),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Center(
                                child: Text('${e.key + 1}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                Positioned(
                  right: 12, bottom: 12,
                  child: FloatingActionButton.small(
                    onPressed: _locating ? null : _goToCurrentLocation,
                    child: _locating
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.my_location_rounded),
                  ),
                ),
                if (_points.isEmpty)
                  Center(
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Tap the map to add points',
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_points.length} point${_points.length == 1 ? '' : 's'} added'
          '${isClosed ? ' · Long-press a marker to delete it' : ' (need 3+ for polygon)'}',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),

        if (_points.isNotEmpty) ...[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Polygon Points',
                        style: TextStyle(fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => setState(() => _points.clear()),
                      icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                      label: const Text('Clear All'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...(_points.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('${e.key + 1}',
                            style: const TextStyle(color: Colors.white,
                                fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${e.value.latitude.toStringAsFixed(6)}, '
                      '${e.value.longitude.toStringAsFixed(6)}',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary,
                          fontFamily: 'monospace'),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 16, color: AppColors.textMuted),
                      onPressed: () => _removePoint(e.key),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ]),
                ))),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        PrimaryButton(
          label: _existingConfig != null ? 'Update Geofence' : 'Save Geofence',
          icon: Icons.save_rounded,
          isLoading: _saving,
          width: double.infinity,
          onPressed: isClosed ? _save : null,
        ),
        if (_existingConfig != null) ...[
          const SizedBox(height: 8),
          Text(
            'Current geofence: "${_existingConfig!.name}" '
            '(${_existingConfig!.polygonPoints.length} points)',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String text;
  const _Step(this.number, this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 20, height: 20,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(number, style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: AppColors.primary)),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(text,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
    ]),
  );
}
