import 'dart:io';

import 'package:dionysos/utils/log.dart';
import 'package:win32_registry/win32_registry.dart';

class AppLinksHelper {
  static Future<void> registerScheme(String scheme) async {
    if (!Platform.isWindows) {
      logger.i('Skipping protocol registration: not on Windows');
      return;
    }

    try {
      final String appPath = Platform.resolvedExecutable;

      final String protocolRegKey = 'Software\\Classes\\$scheme';
      const RegistryValue protocolRegValue = RegistryValue(
        'URL Protocol',
        RegistryValueType.string,
        '',
      );
      const String protocolCmdRegKey = 'shell\\open\\command';
      final RegistryValue protocolCmdRegValue = RegistryValue(
        '',
        RegistryValueType.string,
        '"$appPath" "%1"',
      );

      final regKey = Registry.currentUser.createKey(protocolRegKey);
      regKey.createValue(protocolRegValue);
      regKey.createKey(protocolCmdRegKey).createValue(protocolCmdRegValue);

      logger.i('Successfully registered protocol: $scheme');
    } catch (e, stack) {
      logger.e(
        'Failed to register protocol: $scheme',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  static Future<void> unregisterScheme(String scheme) async {
    if (!Platform.isWindows) {
      logger.i('Skipping protocol unregistration: not on Windows');
      return;
    }

    try {
      final String protocolRegKey = 'Software\\Classes\\$scheme';
      Registry.currentUser.deleteKey(protocolRegKey);
      logger.i('Successfully unregistered protocol: $scheme');
    } catch (e, stack) {
      logger.e(
        'Failed to unregister protocol: $scheme',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  static Future<bool> isSchemeRegistered(String scheme) async {
    if (!Platform.isWindows) {
      return false;
    }

    try {
      final String protocolRegKey = 'Software\\Classes\\$scheme';
      Registry.openPath(RegistryHive.currentUser, path: protocolRegKey);
      return true;
    } catch (e) {
      return false;
    }
  }
}
