import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/attendance_models.dart';
import '../../../services/attendance_service.dart';
import '../../../services/geofence_service.dart';
import '../../../services/qr_hash_service.dart';
import '../../../shared/widgets/widgets.dart';
import '../widgets/qr_scanner_view.dart';

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

  Future<void> _doGeofenceCheck() async {
    if (!mounted) return;
    setState(() {
      _step = _Step.checking;
      _errorMessage = null;
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
      await _requestCameraAndScan();
    } catch (e) {
      _timeoutTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _step = _Step.error;
        _errorMessage = 'Location error: $e';
      });
    }
  }

  Future<void> _requestCameraAndScan() async {
    if (!mounted) return;
    setState(() => _step = _Step.scanning);
  }

  Future<void> _submitAttendance(String raw) async {
    if (!mounted) return;
    setState(() { _step = _Step.result; _submitting = true; });

    final payload = QrHashService.parsePayload(raw);
    if (payload == null) {
      setState(() {
        _submitting = false;
        _success = false;
        _errorMessage = 'Invalid QR code. Make sure you are scanning the Schedulify attendance QR.';
      });
      return;
    }

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
      setState(() {
        _submitting = false;
        _success = res['success'] == true;
        if (!_success) {
          _errorMessage = _friendlyError(res['error'] as String? ?? 'unknown');
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
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
      _Step.scanning => QrScannerView(
          onCodeDetected: _submitAttendance),
      _Step.error    => _ErrorView(
          message: _errorMessage ?? 'Unknown error',
          onRetry: _doGeofenceCheck),
      _Step.result   => _ResultView(
          success: _success,
          submitting: _submitting,
          message: _errorMessage,
          onDone: () => Navigator.of(context).pop()),
    },
  );
}

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

// _ScanningView is replaced by QrScannerView in qr_scanner_view.dart.
// It is intentionally not defined here.

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
      ]),
    ),
  );
}

class _ResultView extends StatelessWidget {
  final bool success;
  final bool submitting;
  final String? message;
  final VoidCallback onDone;
  const _ResultView({required this.success, required this.submitting,
      this.message, required this.onDone});

  @override
  Widget build(BuildContext context) {
    if (submitting) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Recording attendance…',
              style: TextStyle(color: AppColors.textSecondary)),
        ]),
      );
    }
    return Center(
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
}

enum _Step { checking, scanning, error, result }
