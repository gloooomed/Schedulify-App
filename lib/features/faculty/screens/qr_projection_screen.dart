import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/qr_hash_service.dart';

class QrProjectionScreen extends ConsumerWidget {
  const QrProjectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(activeSessionProvider);

    return sessionAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
      data: (session) {
        if (session == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Attendance')),
            body: const Center(child: Text('No active session')),
          );
        }
        return _ProjectionView(sessionId: session.id,
            courseName: session.courseName ?? 'Attendance');
      },
    );
  }
}

class _ProjectionView extends ConsumerStatefulWidget {
  final String sessionId;
  final String courseName;
  const _ProjectionView({required this.sessionId, required this.courseName});

  @override
  ConsumerState<_ProjectionView> createState() => _ProjectionViewState();
}

class _ProjectionViewState extends ConsumerState<_ProjectionView> {
  bool _fullscreen = false;

  void _toggleFullscreen() {
    setState(() => _fullscreen = !_fullscreen);
    if (_fullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  Future<void> _endSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('End Session?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
            'This will stop the QR and mark the session as ended. '
            'Students will no longer be able to check in.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Session',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(activeSessionProvider.notifier).end();
    if (mounted) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(activeSessionProvider);

    final attendeesAsync =
        ref.watch(sessionAttendeesProvider(widget.sessionId));
    final attendeeCount = attendeesAsync.valueOrNull?.length ?? 0;

    final payload = QrHashService.buildPayload(widget.sessionId);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _fullscreen
          ? null
          : AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text(widget.courseName,
                  style: const TextStyle(color: Colors.white)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
                  onPressed: _toggleFullscreen,
                  tooltip: 'Fullscreen (projector mode)',
                ),
                IconButton(
                  icon: const Icon(Icons.stop_circle_rounded,
                      color: AppColors.danger),
                  onPressed: _endSession,
                  tooltip: 'End session',
                ),
              ],
            ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_fullscreen)
                      const Text('Show this QR to students',
                          style: TextStyle(color: Colors.white54, fontSize: 14)),
                    if (!_fullscreen) const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: QrImageView(
                        data: payload,
                        version: QrVersions.auto,
                        size: _fullscreen ? 340 : 260,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    _RotationIndicator(sessionId: widget.sessionId),

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.people_rounded,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text('$attendeeCount student${attendeeCount == 1 ? '' : 's'} marked present',
                            style: const TextStyle(color: Colors.white,
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ],
                ),
              ),
            ),

            if (_fullscreen)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  IconButton(
                    onPressed: _toggleFullscreen,
                    icon: const Icon(Icons.fullscreen_exit_rounded,
                        color: Colors.white54, size: 28),
                  ),
                  const SizedBox(width: 32),
                  ElevatedButton.icon(
                    onPressed: _endSession,
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('End Session'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class _RotationIndicator extends StatefulWidget {
  final String sessionId;
  const _RotationIndicator({required this.sessionId});

  @override
  State<_RotationIndicator> createState() => _RotationIndicatorState();
}

class _RotationIndicatorState extends State<_RotationIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 5))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final remaining = 5 - (_ctrl.value * 5).floor();
        return Text('Refreshes in ${remaining}s',
            style: const TextStyle(color: Colors.white38, fontSize: 12));
      },
    ),
    const SizedBox(height: 6),
    SizedBox(
      width: 200,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => LinearProgressIndicator(
          value: _ctrl.value,
          backgroundColor: Colors.white10,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ),
  ]);
}
