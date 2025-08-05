import 'package:dionysos/utils/service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferenceService {
  late final SharedPreferences _preferences;
  late final String _prefix;
  Future<void> init() async {
    if (kDebugMode) {
      _prefix = 'debug_';
    } else {
      _prefix = '';
    }
    _preferences = await SharedPreferences.getInstance();
  }

  String? getString(String key) => _preferences.getString(_prefix + key);

  Future<void> setString(String key, String value) =>
      _preferences.setString(key, value);

  Future<void> remove(String key) => _preferences.remove(_prefix + key);

  bool containsKey(String key) => _preferences.containsKey(_prefix + key);

  static Future<void> ensureInitialized() async {
    final service = PreferenceService();
    await service.init();
    register(service);
  }
}
