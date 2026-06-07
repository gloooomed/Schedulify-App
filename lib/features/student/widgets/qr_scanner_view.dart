import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// A self-contained QR scanner view built on [MobileScanner].
///
/// Responsibilities owned here (not in the caller):
///   - Camera lifecycle (controller start/stop/dispose)
///   - Inline camera error display
///   - 5-second re-scan cooldown to prevent duplicate firings
///   - Viewfinder overlay with corner brackets
///
/// The caller only needs to handle [onCodeDetected] with the raw QR string.
class QrScannerView extends StatefulWidget {
  /// Called at most once every [cooldown] with the decoded raw QR value.
  final ValueChanged<String> onCodeDetected;

  /// How long to lock the scanner after a detection (prevents duplicates).
  final Duration cooldown;

  const QrScannerView({
    super.key,
    required this.onCodeDetected,
    this.cooldown = const Duration(seconds: 5),
  });

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView> {
  String? _cameraError;
  bool _locked = false;
  Timer? _cooldownTimer;
  int _retryKey = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_locked) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    // Lock immediately so no duplicate fires during the cooldown window.
    _locked = true;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(widget.cooldown, () {
      if (mounted) setState(() => _locked = false);
    });

    widget.onCodeDetected(raw);
  }

  void _onError(MobileScannerException error) {
    setState(() {
      _cameraError = switch (error.errorCode) {
        MobileScannerErrorCode.permissionDenied =>
          'Camera permission denied.\nTap Retry to request access.',
        MobileScannerErrorCode.unsupported =>
          'Camera not supported on this device.',
        _ => 'Camera error: ${error.errorCode.name}. Tap Retry.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraError != null) {
      return _CameraErrorView(
        message: _cameraError!,
        onRetry: () => setState(() {
          _cameraError = null;
          _retryKey++;
        }),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Live camera feed ──────────────────────────────────────────────
        MobileScanner(
          key: ValueKey(_retryKey),
          fit: BoxFit.cover,
          onDetect: _onDetect,
          errorBuilder: (context, error, child) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _onError(error));
            return child ?? const SizedBox.shrink();
          },
        ),

        // ── Semi-transparent dimming outside the finder box ───────────────
        CustomPaint(painter: _ViewfinderPainter()),

        // ── Corner bracket overlay ────────────────────────────────────────
        const Center(child: _ViewfinderBrackets()),

        // ── Bottom hint bar ───────────────────────────────────────────────
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 44),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(179),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Point the camera at the QR code\ndisplayed by your faculty',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
            ),
          ),
        ),

        // ── Locked indicator (subtle pulse after a detection) ─────────────
        if (_locked)
          const Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: Center(
              child: _ScannedChip(),
            ),
          ),
      ],
    );
  }
}

// ── Camera error fallback ─────────────────────────────────────────────────────

class _CameraErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _CameraErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(38),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.videocam_off_rounded,
                  color: Colors.red, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'Camera Unavailable',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white30),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chip shown briefly after a code is captured ───────────────────────────────

class _ScannedChip extends StatelessWidget {
  const _ScannedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade700.withAlpha(230),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline_rounded,
              color: Colors.white, size: 16),
          SizedBox(width: 6),
          Text('QR detected — processing…',
              style: TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Viewfinder dimming painter ────────────────────────────────────────────────

class _ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const boxSize = 240.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rect = Rect.fromCenter(
        center: Offset(cx, cy), width: boxSize, height: boxSize);

    final paint = Paint()..color = Colors.black.withAlpha(140);
    // Fill everything except the clear window.
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ViewfinderPainter old) => false;
}

// ── Corner bracket decoration ─────────────────────────────────────────────────

class _ViewfinderBrackets extends StatelessWidget {
  const _ViewfinderBrackets();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 240,
      child: CustomPaint(painter: _BracketPainter()),
    );
  }
}

class _BracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const len = 28.0;
    const thickness = 3.5;
    const radius = 12.0;
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final corners = [
      // top-left
      [Offset(radius, 0), Offset(0, 0), Offset(0, radius), Offset(len, 0), Offset(0, len)],
      // top-right
      [
        Offset(size.width - radius, 0),
        Offset(size.width, 0),
        Offset(size.width, radius),
        Offset(size.width - len, 0),
        Offset(size.width, len)
      ],
      // bottom-left
      [
        Offset(0, size.height - radius),
        Offset(0, size.height),
        Offset(radius, size.height),
        Offset(0, size.height - len),
        Offset(len, size.height)
      ],
      // bottom-right
      [
        Offset(size.width, size.height - radius),
        Offset(size.width, size.height),
        Offset(size.width - radius, size.height),
        Offset(size.width, size.height - len),
        Offset(size.width - len, size.height)
      ],
    ];

    for (final c in corners) {
      canvas.drawLine(c[0], c[2], paint); // arc approximation via two lines
      canvas.drawLine(c[3], c[1], paint);
      canvas.drawLine(c[1], c[4], paint);
    }
  }

  @override
  bool shouldRepaint(_BracketPainter old) => false;
}
