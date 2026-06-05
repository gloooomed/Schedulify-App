import 'dart:convert';
import 'package:crypto/crypto.dart';

class QrHashService {
  QrHashService._();

  static String current(String sessionId) => _hash(sessionId, _window());

  static String forTimestamp(String sessionId, int epochMs) =>
      _hash(sessionId, epochMs ~/ 5000);

  static String buildPayload(String sessionId) =>
      'schedulify:$sessionId:${current(sessionId)}';

  static QrPayload? parsePayload(String raw) {
    final parts = raw.split(':');
    if (parts.length != 3 || parts[0] != 'schedulify') return null;
    return QrPayload(sessionId: parts[1], hash: parts[2]);
  }

  static int _window() => DateTime.now().millisecondsSinceEpoch ~/ 5000;

  static String _hash(String sessionId, int window) {
    final input = '$sessionId:$window';
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString().substring(0, 32);
  }
}

class QrPayload {
  final String sessionId;
  final String hash;
  const QrPayload({required this.sessionId, required this.hash});
}
