import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/config_store.dart';

class SupabaseClientManager {
  static SupabaseClientManager? _instance;
  static SupabaseClientManager get instance =>
      _instance ??= SupabaseClientManager._();
  SupabaseClientManager._();

  SupabaseClient? _client;

  SupabaseClient get client {
    if (_client != null) return _client!;
    final config = ConfigStore.instance.get();
    if (config == null) {
      throw StateError('Supabase not configured. Complete college setup first.');
    }
    _client = SupabaseClient(config.supabaseUrl, config.supabaseAnonKey);
    return _client!;
  }

  void reset() {
    _client = null;
  }

  static Future<String?> testConnection(String rawUrl, String anonKey) async {
    try {
      var url = rawUrl.trim();
      if (!url.startsWith('http')) url = 'https://$url';
      url = url.replaceAll(RegExp(r'/$'), '');

      final response = await http.get(
        Uri.parse('$url/auth/v1/health'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) return null;

      final res2 = await http.get(
        Uri.parse('$url/rest/v1/'),
        headers: {
          'apikey': anonKey.trim(),
          'Authorization': 'Bearer ${anonKey.trim()}',
        },
      ).timeout(const Duration(seconds: 10));

      if (res2.statusCode < 500) return null;
      return 'Server error (${res2.statusCode}). Try again later.';
    } on http.ClientException catch (e) {
      return 'Network error: ${e.message}';
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('timeout') || msg.contains('TimeoutException')) {
        return 'Connection timed out. Check the URL and your internet connection.';
      }
      return 'Could not reach Supabase: $msg';
    }
  }
}

SupabaseClient get supabase => SupabaseClientManager.instance.client;
