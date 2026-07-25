import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Lightweight client-side file optimizer.
///
/// Strategy (per file type):
///   PNG / JPG → re-encode as JPEG at 85 quality  (~40-60% size reduction)
///   ZIP / PDF / DOCX → pass through unchanged (already compressed or unsafe to touch)
///
/// Throws [FileTooLargeException] if the *final* byte size exceeds [maxMb].
class FileOptimizer {
  FileOptimizer._();

  /// Compress [bytes] if the extension warrants it, then enforce [maxMb].
  ///
  /// [fileName] is used only for extension detection.
  static Future<Uint8List> compress(
    Uint8List bytes,
    String fileName, {
    int maxMb = 10,
    int jpegQuality = 85,
  }) async {
    final ext = fileName.split('.').last.toLowerCase();
    Uint8List result = bytes;

    if (ext == 'png' || ext == 'jpg' || ext == 'jpeg') {
      result = await _compressImage(bytes, jpegQuality);
    }
    // All other formats (pdf, docx, zip, rar, …) → unchanged.

    final sizeMb = result.lengthInBytes / (1024 * 1024);
    if (sizeMb > maxMb) {
      throw FileTooLargeException(
        'File is ${sizeMb.toStringAsFixed(1)} MB, '
        'which exceeds the ${maxMb} MB limit.',
      );
    }

    return result;
  }

  // ---------------------------------------------------------------------------

  /// Re-encodes image bytes as JPEG at [quality] (0–100).
  /// Falls back to the original bytes if decoding fails.
  static Future<Uint8List> _compressImage(Uint8List bytes, int quality) async {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes; // unknown format – skip
      final encoded = img.encodeJpg(decoded, quality: quality);
      // Only return the compressed version if it's actually smaller.
      if (encoded.length < bytes.length) {
        return Uint8List.fromList(encoded);
      }
      return bytes;
    } catch (_) {
      // Never crash the upload because of a compression failure.
      return bytes;
    }
  }
}

class FileTooLargeException implements Exception {
  final String message;
  const FileTooLargeException(this.message);
  @override
  String toString() => message;
}
