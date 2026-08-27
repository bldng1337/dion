import 'dart:async';

import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/service/periodic_service.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/version.dart';
import 'package:flutter/foundation.dart';

const int _maxPagesPerRepo = 5;

class ExtensionUpdateJob extends PeriodicJob {
  @override
  String get taskName => 'extensionUpdates';

  @override
  String get displayName => 'Extension updates';

  @override
  Setting<bool, dynamic> get enabledSetting =>
      settings.extension.autoUpdate.enabled;

  @override
  Setting<int, dynamic> get intervalSetting =>
      settings.extension.autoUpdate.interval;

  @override
  Future<void> run() async {
    final sourceExt = locate<ExtensionService>();
    final repos = settings.extension.repositories.value;
    if (repos.isEmpty) return;

    final installed = sourceExt.getExtensions().toList(growable: false);
    final installedIds = installed.map((e) => e.id).toSet();

    for (final repoUrl in repos) {
      try {
        final repo = await sourceExt.getRepo(repoUrl);
        for (var page = 1; page <= _maxPagesPerRepo; page++) {
          final res = await repo.browse(page: page);
          if (res.isEmpty) break;
          for (final remote in res) {
            if (installedIds.contains(remote.id)) {
              final inst = installed.firstWhere((e) => e.id == remote.id);
              if (parseVersion(remote.version) > inst.version) {
                if (await declaresNewPermissions(remote, inst)) {
                  logger.i(
                    'Extension ${remote.id} ${remote.version} requires new permissions; skipping auto-update',
                  );
                  continue;
                }
                logger.i(
                  'Updating extension ${remote.id} from ${inst.version} to ${remote.version}',
                );
                await remote.install();
              }
            }
          }
        }
      } catch (e) {
        logger.e('Update check failed for $repoUrl', error: e);
      }
    }
  }

}

class ExtensionUpdateService {
  final ValueNotifier<Map<String, RemoteExtension>> updates = ValueNotifier({});

  final ValueNotifier<bool> checking = ValueNotifier(false);

  static Future<void> ensureInitialized() async {
    final service = ExtensionUpdateService();
    register<ExtensionUpdateService>(service);
    logger.i('Initialised ExtensionUpdateService!');
  }

  Future<void> checkNow() async {
    if (checking.value) return;
    checking.value = true;
    try {
      updates.value = await _findUpdates();
      logger.i(
        'Extension update foreground check complete: ${updates.value.length} updates',
      );
    } catch (e, stack) {
      logger.e('Extension update check failed', error: e, stackTrace: stack);
    } finally {
      checking.value = false;
    }
  }

  void markUpdated(String id) {
    if (updates.value.containsKey(id)) {
      updates.value = {...updates.value}..remove(id);
    }
  }

  Future<Map<String, RemoteExtension>> _findUpdates() async {
    final sourceExt = locate<ExtensionService>();
    final repos = settings.extension.repositories.value;
    if (repos.isEmpty) return {};

    final installed = sourceExt.getExtensions().toList(growable: false);
    final installedIds = installed.map((e) => e.id).toSet();
    final Map<String, RemoteExtension> found = {};

    for (final repoUrl in repos) {
      try {
        final repo = await sourceExt.getRepo(repoUrl);
        for (var page = 1; page <= _maxPagesPerRepo; page++) {
          final res = await repo.browse(page: page);
          if (res.isEmpty) break;
          for (final remote in res) {
            if (installedIds.contains(remote.id)) {
              final inst = installed.firstWhere((e) => e.id == remote.id);
              if (parseVersion(remote.version) > inst.version) {
                found[remote.id] = remote;
              }
            }
          }
        }
      } catch (e) {
        logger.e('Update check failed for $repoUrl', error: e);
      }
    }

    return found;
  }

  void dispose() {
    updates.dispose();
    checking.dispose();
  }
}
