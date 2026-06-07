/// Stub used on non-web platforms.
/// On native (Android/iOS) this class always returns false,
/// so the PWA prompt is never shown.
class PwaDetector {
  static bool shouldShow() => false;
}
