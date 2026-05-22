import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String? serviceRoleKey; // stored locally only, never sent to our servers
  final String? collegeName;
  final String? collegeId;
  final bool setupComplete;

  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.serviceRoleKey,
    this.collegeName,
    this.collegeId,
    required this.setupComplete,
  });
}

class ConfigStore {
  static const _keyUrl            = 'schedulify_supabase_url';
  static const _keyAnonKey        = 'schedulify_anon_key';
  static const _keyServiceRole    = 'schedulify_service_role_key';
  static const _keyCollegeName    = 'schedulify_college_name';
  static const _keyCollegeId      = 'schedulify_college_id';
  static const _keySetupComplete  = 'schedulify_setup_complete';

  static ConfigStore? _instance;
  static ConfigStore get instance => _instance ??= ConfigStore._();
  ConfigStore._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  AppConfig? get() {
    final url     = _prefs?.getString(_keyUrl);
    final anonKey = _prefs?.getString(_keyAnonKey);
    final setupComplete = _prefs?.getBool(_keySetupComplete) ?? false;
    if (url == null || anonKey == null) return null;
    return AppConfig(
      supabaseUrl:    url,
      supabaseAnonKey: anonKey,
      serviceRoleKey: _prefs?.getString(_keyServiceRole),
      collegeName:    _prefs?.getString(_keyCollegeName),
      collegeId:      _prefs?.getString(_keyCollegeId),
      setupComplete:  setupComplete,
    );
  }

  Future<void> set(AppConfig config) async {
    await _prefs?.setString(_keyUrl, config.supabaseUrl);
    await _prefs?.setString(_keyAnonKey, config.supabaseAnonKey);
    await _prefs?.setBool(_keySetupComplete, config.setupComplete);
    if (config.serviceRoleKey != null) {
      await _prefs?.setString(_keyServiceRole, config.serviceRoleKey!);
    }
    if (config.collegeName != null) {
      await _prefs?.setString(_keyCollegeName, config.collegeName!);
    }
    if (config.collegeId != null) {
      await _prefs?.setString(_keyCollegeId, config.collegeId!);
    }
  }

  Future<void> clear() async {
    await _prefs?.remove(_keyUrl);
    await _prefs?.remove(_keyAnonKey);
    await _prefs?.remove(_keyServiceRole);
    await _prefs?.remove(_keyCollegeName);
    await _prefs?.remove(_keyCollegeId);
    await _prefs?.setBool(_keySetupComplete, false);
  }

  bool get isReady => get()?.setupComplete == true;
}
