import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Conditional import: only the web variant accesses dart:js_interop.
import 'pwa_prompt_stub.dart'
    if (dart.library.js_interop) 'pwa_prompt_web.dart';

/// Shows an "Add to Home Screen" bottom sheet after login,
/// but ONLY when running as a web app on iOS Safari (not yet installed as PWA).
///
/// Usage: call [PwaPrompt.showIfNeeded] after navigating post-login.
class PwaPrompt {
  PwaPrompt._();

  static bool _alreadyShown = false;

  static Future<void> showIfNeeded(BuildContext context) async {
    if (!kIsWeb) return;
    if (_alreadyShown) return;
    if (!PwaDetector.shouldShow()) return;

    _alreadyShown = true;
    await Future.delayed(const Duration(milliseconds: 700));
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _InstallHintSheet(),
    );
  }
}

class _InstallHintSheet extends StatelessWidget {
  const _InstallHintSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header row
              Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.schedule_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Install Schedulify',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text('Get the full app experience on iOS',
                          style: TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              const _StepRow(
                icon: Icons.ios_share_rounded,
                text: 'Tap the Share button',
                sub: 'at the bottom of your browser bar',
              ),
              const SizedBox(height: 12),
              const _StepRow(
                icon: Icons.add_box_outlined,
                text: 'Tap "Add to Home Screen"',
                sub: 'then tap Add in the top right',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.white.withAlpha(15),
                  ),
                  child: const Text('Maybe later',
                      style: TextStyle(color: Colors.white70, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final String sub;
  const _StepRow(
      {required this.icon, required this.text, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(13),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
      const SizedBox(width: 14),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          Text(sub,
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    ]);
  }
}
