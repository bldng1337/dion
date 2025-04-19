import 'package:dionysos/data/appsettings.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferenceService {
  late final SharedPreferences _preferences;

  Future<void> init() async {
    settings; //Needed so that the preferenceCollection is initialized
    _preferences = await SharedPreferences.getInstance();
    for (final setting in preferenceCollection.settings) {
      final id = '${kDebugMode ? 'debug.' : ''}${setting.metadata.id}';
      final value = _preferences.getString(id);
      if (value != null) {
        try {
          setting.value = setting.metadata.parse(value);
        } catch (e, stack) {
          logger.e('Error loading preference', error: e, stackTrace: stack);
          _preferences.remove(id);
        }
      }

      setting.addListener(() {
        try {
          _preferences.setString(
            id,
            setting.metadata.stringify(setting.value),
          );
        } catch (e, stack) {
          logger.e(
            'Error saving preference $setting',
            error: e,
            stackTrace: stack,
          );
          _preferences.remove(id);
        }
      });
    }
  }

  static Future<void> ensureInitialized() async {
    final service = PreferenceService();
    await service.init();
    register(service);
  }
}
