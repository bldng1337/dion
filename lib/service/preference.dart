import 'package:dionysos/data/appsettings.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferenceService {
  late final SharedPreferences _preferences;

  Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
    for (final setting in preferenceCollection.settings) {
      logger.i('Loading preference ${setting.metadata.id}');
      final value = _preferences.getString(setting.metadata.id);
      if (value != null) {
        try {
          setting.value = setting.metadata.parse(value);
        } catch (e, stack) {
          logger.e('Error loading preference', error: e, stackTrace: stack);
          _preferences.remove(setting.metadata.id);
        }
      }
      
      setting.addListener(() {
        logger.i('Saving preference ${setting.metadata.id}');
        try {
          _preferences.setString(
            setting.metadata.id,
            setting.metadata.stringify(setting.value),
          );
        } catch (e, stack) {
          logger.e(
            'Error saving preference',
            error: e,
            stackTrace: stack,
          );
          _preferences.remove(setting.metadata.id);
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
