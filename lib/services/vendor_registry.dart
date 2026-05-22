import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

// Central vendor Supabase credentials (set in .env / build config)
const _vendorUrl = String.fromEnvironment('VENDOR_SUPABASE_URL', defaultValue: '');
const _vendorAnonKey = String.fromEnvironment('VENDOR_SUPABASE_ANON_KEY', defaultValue: '');
const _vendorAccessCode = String.fromEnvironment('VENDOR_ACCESS_CODE', defaultValue: 'SCHEDULIFY2025');

class VendorRegistry {
  static VendorRegistry? _instance;
  static VendorRegistry get instance => _instance ??= VendorRegistry._();
  VendorRegistry._();

  SupabaseClient? _client;

  // Lazy init — client is created only when first used, not at app startup.
  // This prevents DNS failures from blocking the app on physical devices.
  void init() { /* no-op: client is created lazily */ }

  SupabaseClient get _registry {
    _client ??= SupabaseClient(_vendorUrl, _vendorAnonKey);
    return _client!;
  }
  bool verifyAccessCode(String code) => code == _vendorAccessCode;

  Future<RegisteredCollege?> getCollegeConfig(String collegeId) async {
    final res = await _registry
        .from('registered_colleges')
        .select()
        .eq('college_id', collegeId)
        .eq('status', 'active')
        .maybeSingle();
    if (res == null) return null;
    return RegisteredCollege.fromJson(res);
  }

  Future<bool> checkCollegeIdExists(String collegeId) async {
    final res = await _registry
        .from('registered_colleges')
        .select('id')
        .eq('college_id', collegeId)
        .maybeSingle();
    return res != null;
  }

  Future<String> generateCollegeId(String collegeName) async {
    final words = collegeName.split(RegExp(r'\s+')).take(3);
    final initials = words.map((w) => w[0].toUpperCase()).join();
    final suffix = List.generate(4, (_) {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final idx = DateTime.now().microsecond % chars.length;
      return chars[idx];
    }).join();
    final id = '$initials-$suffix';
    final exists = await checkCollegeIdExists(id);
    if (exists) return generateCollegeId(collegeName); // retry
    return id;
  }

  Future<String> registerCollege({
    required String collegeName,
    required String contactEmail,
    required String supabaseUrl,
    required String anonKey,
  }) async {
    final collegeId = await generateCollegeId(collegeName);
    await _registry.from('registered_colleges').insert({
      'college_id': collegeId,
      'college_name': collegeName,
      'contact_email': contactEmail,
      'supabase_url': supabaseUrl,
      'anon_key': anonKey,
      'status': 'active',
    });
    return collegeId;
  }
}
