import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight key-value cache backed by SharedPreferences.
/// Every entry is stored with a timestamp; reads past [ttl] return null.
class CacheService {
  static const _prefix = 'schedulify_cache_';
  static const _tsSuffix = '_ts';

  /// Write [data] (JSON-encodable map or list) under [key] with a [ttl].
  static Future<void> write(String key, dynamic data,
      {Duration ttl = const Duration(hours: 24)}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefix + key, jsonEncode(data));
    await prefs.setInt(
        _prefix + key + _tsSuffix, DateTime.now().millisecondsSinceEpoch);
  }

  /// Read cached data for [key]. Returns null if missing or expired.
  static Future<dynamic> read(String key,
      {Duration ttl = const Duration(hours: 24)}) async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_prefix + key + _tsSuffix);
    if (ts == null) return null;
    final age = DateTime.now().millisecondsSinceEpoch - ts;
    if (age > ttl.inMilliseconds) return null;
    final raw = prefs.getString(_prefix + key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  /// Remove a specific cache entry.
  static Future<void> evict(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefix + key);
    await prefs.remove(_prefix + key + _tsSuffix);
  }

  /// Clear all Schedulify cache entries.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
