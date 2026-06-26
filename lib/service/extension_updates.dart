import 'dart:async';

import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/service/preference.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/version.dart';
import 'package:flutter/foundation.dart';

const Duration _foregroundCheckInterval = Duration(minutes: 15);

const int _maxPagesPerRepo = 5;

class ExtensionUpdateService {
  Timer? _timer;
  DateTime? _lastCheck;

  final ValueNotifier<Map<String, RemoteExtension>> updates = ValueNotifier({});

  final ValueNotifier<bool> checking = ValueNotifier(false);

  static Future<void> ensureInitialized() async {
    final service = ExtensionUpdateService();
    await service.init();
    register<ExtensionUpdateService>(service);
    logger.i('Initialised ExtensionUpdateService!');
  }

  Future<void> init() async {
    // Ensure PreferenceService is registered before touching settings, since
    // AppLoader runs all tasks concurrently and the settings lazy-init calls
    await locateAsync<PreferenceService>();

    settings.extension.autoUpdate.enabled.addListener(_onSettingsChanged);
    settings.extension.autoUpdate.interval.addListener(_onSettingsChanged);

    _startTimer();

    // Populate updates shortly after startup without blocking the loading
    if (settings.extension.autoUpdate.enabled.value) {
      unawaited(_initialCheck());
    }
  }

  void _onSettingsChanged() => _startTimer();

  void _startTimer() {
    _timer?.cancel();
    if (!settings.extension.autoUpdate.enabled.value) return;
    _timer = Timer.periodic(_foregroundCheckInterval, (_) => _maybeCheck());
  }

  Future<void> _initialCheck() async {
    await Future.delayed(const Duration(seconds: 5));
    await _maybeCheck();
  }

  Future<void> _maybeCheck() async {
    final intervalHours = settings.extension.autoUpdate.interval.value;
    if (_lastCheck != null &&
        DateTime.now().difference(_lastCheck!).inHours < intervalHours) {
      return;
    }
    await checkNow();
  }

  Future<void> checkNow() async {
    if (checking.value) return;
    checking.value = true;
    _lastCheck = DateTime.now();
    try {
      updates.value = await _findUpdates();
      logger.i(
        'Extension update check complete: ${updates.value.length} updates',
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
    _timer?.cancel();
    settings.extension.autoUpdate.enabled.removeListener(_onSettingsChanged);
    settings.extension.autoUpdate.interval.removeListener(_onSettingsChanged);
  }
}
