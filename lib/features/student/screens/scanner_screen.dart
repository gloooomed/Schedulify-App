import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/attendance_models.dart';
import '../../../services/attendance_service.dart';
import '../../../services/geofence_service.dart';
import '../../../services/qr_hash_service.dart';
import '../../../shared/widgets/widgets.dart';

/// Scanner screen — student flow:
/// Step 1: Location check (geofence)
/// Step 2: Camera permission
/// Step 3: QR scan
/// Step 4: Result
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  _Step _step = _Step.checking;
  String? _errorMessage;
  bool _success = false;
  bool _submitting = false;
  bool _scanned = false;
  GeofenceResult? _geoResult;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _doGeofenceCheck();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  // ── Step 1: Geofence ──────────────────────────────────────

  Future<void> _doGeofenceCheck() async {
    if (!mounted) return;
    setState(() {
      _step = _Step.checking;
      _errorMessage = null;
      _scanned = false;
    });

    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 20), () {
      if (mounted && _step == _Step.checking) {
        setState(() {
          _step = _Step.error;
          _errorMessage =
              'Location check timed out (20s).\n\n'
              'Emulator: set a mock GPS in Extended Controls → Location.\n'
              'Real device: enable Location and try outdoors.';
        });
      }
    });

    try {
      final result = await GeofenceService.checkPresence();
      _timeoutTimer?.cancel();
      if (!mounted) return;

      if (result == null) {
        setState(() {
          _step = _Step.error;
          _errorMessage = 'Could not get location.\n'
              'Grant Location permission in Settings → Apps → Schedulify → Permissions.';
        });
        return;
      }
      if (result.isMocked) {
        setState(() {
          _step = _Step.error;
          _errorMessage = 'Fake GPS detected. Real location required.';
        });
        return;
      }
      if (!result.isInside) {
        setState(() {
          _step = _Step.error;
          _errorMessage =
              'You are outside the campus boundary.\n\n'
              'GPS: ${result.lat.toStringAsFixed(5)}, ${result.lng.toStringAsFixed(5)}\n'
              'Accuracy: ±${result.accuracy.toStringAsFixed(0)} m\n\n'
              'Ask your admin to expand the geofence if you are inside.';
        });
        return;
      }

      _geoResult = result;
      // Step 2: request camera permission explicitly
      await _requestCameraPermission();
    } catch (e) {
      _timeoutTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _step = _Step.error;
        _errorMessage = 'Location error: $e';
      });
    }
  }

  // ── Step 2: Camera permission ─────────────────────────────

  Future<void> _requestCameraPermission() async {
    if (!mounted) return;

    // Check current status
    var status = await Permission.camera.status;

    if (status.isGranted) {
      // Already granted → go straight to scanner
      setState(() => _step = _Step.scanning);
      return;
    }

    if (status.isPermanentlyDenied) {
      // User permanently denied → direct to settings
      setState(() {
        _step = _Step.error;
        _errorMessage =
            'Camera permission was permanently denied.\n\n'
            'Go to Settings → Apps → Schedulify → Permissions → Camera → Allow.';
      });
      return;
    }

    // Request at runtime
    status = await Permission.camera.request();
    if (!mounted) return;

    if (status.isGranted) {
      setState(() => _step = _Step.scanning);
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _step = _Step.error;
        _errorMessage =
            'Camera permission denied.\n\n'
            'Go to Settings → Apps → Schedulify → Permissions → Camera → Allow,\n'
            'then tap Try Again.';
      });
    } else {
      setState(() {
        _step = _Step.error;
        _errorMessage = 'Camera permission is required to scan the QR code.\nTap Try Again to allow it.';
      });
    }
  }

  // ── Step 3: QR scan result ────────────────────────────────

  Future<void> _onQrDetect(BarcodeCapture capture) async {
    if (_submitting || _scanned) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    final payload = QrHashService.parsePayload(raw);
    if (payload == null) return;

    _scanned = true;
    setState(() => _submitting = true);

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final res = await AttendanceService.markAttendance(
        sessionId: payload.sessionId,
        studentId: user.id,
        qrHash: payload.hash,
        lat: _geoResult!.lat,
        lng: _geoResult!.lng,
        isMocked: _geoResult!.isMocked,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() { _step = _Step.result; _success = true; });
      } else {
        setState(() {
          _step = _Step.result;
          _success = false;
          _errorMessage = _friendlyError(res['error'] as String? ?? 'unknown');
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _Step.result;
        _success = false;
        _errorMessage = 'Network error. Try again.\n$e';
      });
    }
  }

  String _friendlyError(String code) => switch (code) {
    'mock_location'      => 'GPS spoofing detected.',
    'session_not_active' => 'Session is no longer active.',
    'invalid_qr'         => 'QR code expired. Ask faculty to display the latest code.',
    'already_marked'     => 'You have already marked attendance for this session.',
    _                    => 'Something went wrong ($code). Try again.',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mark Attendance')),
    body: switch (_step) {
      _Step.checking => _CheckingView(),
      _Step.error    => _ErrorView(
          message: _errorMessage ?? 'Unknown error',
          onRetry: _doGeofenceCheck,
          onOpenSettings: _step == _Step.error &&
              (_errorMessage?.contains('permanently') ?? false)
              ? openAppSettings
              : null),
      _Step.scanning => _ScannerView(
          onDetect: _onQrDetect,
          submitting: _submitting),
      _Step.result   => _ResultView(
          success: _success,
          message: _errorMessage,
          onDone: () => Navigator.of(context).pop()),
    },
  );
}

// ── Step Views ───────────────────────────────────────────────

class _CheckingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      CircularProgressIndicator(),
      SizedBox(height: 24),
      Text('Verifying your location…',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
      SizedBox(height: 8),
      Text('GPS check in progress',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
    ]),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onOpenSettings;
  const _ErrorView({required this.message, required this.onRetry, this.onOpenSettings});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: AppColors.danger.withAlpha(38),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.location_off_rounded,
              color: AppColors.danger, size: 40),
        ),
        const SizedBox(height: 24),
        const Text('Cannot Check In',
            style: TextStyle(color: AppColors.textPrimary,
                fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        const SizedBox(height: 32),
        PrimaryButton(
          label: 'Try Again',
          icon: Icons.refresh_rounded,
          width: double.infinity,
          onPressed: onRetry,
        ),
        if (onOpenSettings != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_rounded, size: 16),
            label: const Text('Open App Settings'),
          ),
        ],
      ]),
    ),
  );
}

class _ScannerView extends StatelessWidget {
  final void Function(BarcodeCapture) onDetect;
  final bool submitting;
  const _ScannerView({required this.onDetect, required this.submitting});

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      MobileScanner(
        onDetect: onDetect,
        errorBuilder: (ctx, error, child) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.camera_alt_outlined,
                  color: AppColors.danger, size: 48),
              const SizedBox(height: 16),
              const Text('Camera Error',
                  style: TextStyle(color: AppColors.textPrimary,
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Code: ${error.errorCode.name}\n\n'
                'Try closing other camera apps and tap the back button and try again.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
            ]),
          ),
        ),
      ),
      Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 240, height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary, width: 3),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              submitting ? 'Verifying…' : 'Point camera at the QR on the screen',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(204),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.location_on_rounded, color: Colors.white, size: 14),
              SizedBox(width: 4),
              Text('Location verified ✓',
                  style: TextStyle(color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
      if (submitting)
        Container(color: Colors.black54,
            child: const Center(child: CircularProgressIndicator())),
    ],
  );
}

class _ResultView extends StatelessWidget {
  final bool success;
  final String? message;
  final VoidCallback onDone;
  const _ResultView({required this.success, this.message, required this.onDone});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            color: (success ? AppColors.success : AppColors.danger).withAlpha(38),
            shape: BoxShape.circle,
          ),
          child: Icon(
            success ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: success ? AppColors.success : AppColors.danger,
            size: 56,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          success ? 'Attendance Marked!' : 'Check-In Failed',
          style: const TextStyle(color: AppColors.textPrimary,
              fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(
          success
              ? 'Your attendance has been recorded successfully.'
              : (message ?? 'Something went wrong.'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 40),
        PrimaryButton(
          label: 'Done',
          icon: Icons.done_rounded,
          width: double.infinity,
          onPressed: onDone,
        ),
      ]),
    ),
  );
}

enum _Step { checking, error, scanning, result }
