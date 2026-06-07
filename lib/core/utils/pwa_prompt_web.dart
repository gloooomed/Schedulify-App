import 'dart:js_interop';

@JS('window._schedulifyShowPwaPrompt')
external JSBoolean? get _showPwaPrompt;

/// Web implementation: reads the flag set by the inline JS in index.html.
class PwaDetector {
  static bool shouldShow() {
    try {
      return _showPwaPrompt?.toDart ?? false;
    } catch (_) {
      return false;
    }
  }
}
