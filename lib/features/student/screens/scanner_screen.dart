import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/attendance_models.dart';
import '../../../services/attendance_service.dart';
import '../../../services/qr_hash_service.dart';
import '../../../shared/widgets/widgets.dart';

/// Scanner screen — student flow:
/// Step 1: Location check (geofence)
/// Step 2: QR scan
/// Step 3: Result
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
  GeofenceResult? _geoResult;
  MobileScannerController? _scannerCtrl;

  @override
  void initState() {
    super.initState();
    _doGeofenceCheck();
  }

  Future<void> _doGeofenceCheck() async {
    setState(() { _step = _Step.checking; _errorMessage = null; });
    ref.read(geofenceCheckProvider.notifier).check();
    // Listen after triggering
    ref.listenManual(geofenceCheckProvider, (_, next) {
      if (!mounted) return;
      next.whenData((result) {
        if (result == null) {
          setState(() {
            _step = _Step.error;
            _errorMessage = 'Could not get location. Please grant location permission.';
          });
          return;
        }
        if (result.isMocked) {
          setState(() {
            _step = _Step.error;
            _errorMessage = 'Mock/fake GPS detected. Real location required.';
          });
          return;
        }
        if (!result.isInside) {
          setState(() {
            _step = _Step.error;
            _errorMessage =
                'You appear to be outside the campus boundary.\n\n'
                'Your GPS: ${result.lat.toStringAsFixed(5)}, '
                '${result.lng.toStringAsFixed(5)}\n'
                'Accuracy: ±${result.accuracy.toStringAsFixed(0)} m\n\n'
                'If you are inside the building, ask your admin to expand the geofence, '
                'or go outdoors for better GPS signal and try again.';
          });
          return;
        }
        _geoResult = result;
        _openScanner();
      });
    });
  }

  void _openScanner() {
    _scannerCtrl = MobileScannerController();
    setState(() => _step = _Step.scanning);
  }

  Future<void> _onQrDetect(BarcodeCapture capture) async {
    if (_submitting) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    final payload = QrHashService.parsePayload(raw);
    if (payload == null) return;

    setState(() => _submitting = true);
    _scannerCtrl?.stop();

    final user = ref.read(currentUserProvider);
    if (user == null) return;

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
      final errCode = res['error'] as String? ?? 'unknown';
      setState(() {
        _step = _Step.result;
        _success = false;
        _errorMessage = _friendlyError(errCode);
      });
    }
    _scannerCtrl?.dispose();
  }

  String _friendlyError(String code) => switch (code) {
    'mock_location'     => 'GPS spoofing detected.',
    'session_not_active'=> 'Session is no longer active.',
    'invalid_qr'        => 'QR code expired. Ask the faculty to show the latest code.',
    'already_marked'    => 'You have already marked attendance for this session.',
    _                   => 'Something went wrong. Try again.',
  };

  @override
  void dispose() {
    _scannerCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mark Attendance')),
    body: switch (_step) {
      _Step.checking => _CheckingView(),
      _Step.error    => _ErrorView(
          message: _errorMessage ?? 'Unknown error',
          onRetry: _doGeofenceCheck),
      _Step.scanning => _ScannerView(
          controller: _scannerCtrl!,
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
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const CircularProgressIndicator(),
      const SizedBox(height: 24),
      const Text('Verifying your location…',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
      const SizedBox(height: 8),
      Text('GPS check in progress', style: TextStyle(
          color: AppColors.textSecondary, fontSize: 13)),
    ]),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: AppColors.danger.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.location_off_rounded,
              color: AppColors.danger, size: 40),
        ),
        const SizedBox(height: 24),
        Text('Cannot Check In', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 18,
            fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        const SizedBox(height: 32),
        PrimaryButton(
          label: 'Try Again',
          icon: Icons.refresh_rounded,
          width: double.infinity,
          onPressed: onRetry,
        ),
      ]),
    ),
  );
}

class _ScannerView extends StatelessWidget {
  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final bool submitting;
  const _ScannerView({required this.controller, required this.onDetect,
      required this.submitting});

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      MobileScanner(controller: controller, onDetect: onDetect),
      // Overlay
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
              color: AppColors.success.withOpacity(0.8),
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
            color: (success ? AppColors.success : AppColors.danger)
                .withOpacity(0.15),
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
          style: TextStyle(
              color: AppColors.textPrimary, fontSize: 22,
              fontWeight: FontWeight.w800),
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
