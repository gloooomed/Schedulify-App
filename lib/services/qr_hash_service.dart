import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Generates a deterministic SHA-256 QR hash for a given session and
/// 5-second time window. Both the faculty client and the Supabase RPC
/// use the same algorithm, so they always agree on the current hash.
///
/// Window = floor(epoch_ms / 5000)  → changes every 5 seconds exactly.
class QrHashService {
  QrHashService._();

  /// Returns the current valid hash for [sessionId].
  static String current(String sessionId) => _hash(sessionId, _window());

  /// Returns the hash for a specific epoch-millisecond timestamp.
  /// Useful for testing or manually verifying a submitted hash.
  static String forTimestamp(String sessionId, int epochMs) =>
      _hash(sessionId, epochMs ~/ 5000);

  /// Encodes session + hash into a QR payload string.
  /// Format: "schedulify:SESSION_ID:HASH"
  static String buildPayload(String sessionId) =>
      'schedulify:$sessionId:${current(sessionId)}';

  /// Parses a scanned QR payload. Returns null if the format is invalid.
  static QrPayload? parsePayload(String raw) {
    final parts = raw.split(':');
    if (parts.length != 3 || parts[0] != 'schedulify') return null;
    return QrPayload(sessionId: parts[1], hash: parts[2]);
  }

  // ── Internal ─────────────────────────────────────────────

  static int _window() => DateTime.now().millisecondsSinceEpoch ~/ 5000;

  static String _hash(String sessionId, int window) {
    final input = '$sessionId:$window';
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString().substring(0, 32); // 32-char prefix
  }
}

class QrPayload {
  final String sessionId;
  final String hash;
  const QrPayload({required this.sessionId, required this.hash});
}
