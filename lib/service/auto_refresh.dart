import 'dart:async';

import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/service/notification.dart';
import 'package:dionysos/service/preference.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/platform.dart';
import 'package:dionysos/utils/service.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;
import 'package:workmanager/workmanager.dart';

const _taskName = 'autoRefreshEntries';
const _refreshDelay = Duration(seconds: 2);
const _foregroundCheckInterval = Duration(minutes: 15);
const _pageSize = 50;

class AutoRefreshService {
  Timer? _timer;
  DateTime? _lastRefresh;

  static Future<void> ensureInitialized() async {
    final service = AutoRefreshService();
    await service.init();
    register<AutoRefreshService>(service);
    logger.i('Initialised AutoRefreshService!');
  }

  Future<void> init() async {
    final platform = getPlatform();

    // Ensure PreferenceService is registered before accessing settings,
    // since AppLoader runs all tasks concurrently and the settings
    // lazy-init calls locate<PreferenceService>().
    await locateAsync<PreferenceService>();

    settings.library.autoRefresh.enabled.addListener(_onSettingsChanged);
    settings.library.autoRefresh.interval.addListener(_onSettingsChanged);

    if (platform == CPlatform.windows) {
      _startForegroundTimer();
    } else if (settings.library.autoRefresh.enabled.value) {
      _rescheduleBackgroundTask();
    }
  }

  void _onSettingsChanged() {
    final platform = getPlatform();
    if (platform == CPlatform.windows) {
      _restartForegroundTimer();
    } else {
      _rescheduleBackgroundTask();
    }
  }

  // Windows: Timer.periodic fallback
  void _startForegroundTimer() {
    if (!settings.library.autoRefresh.enabled.value) return;
    final intervalHours = settings.library.autoRefresh.interval.value;
    _timer?.cancel();
    _timer = Timer.periodic(_foregroundCheckInterval, (_) {
      _maybeRefresh(intervalHours);
    });
  }

  void _restartForegroundTimer() {
    _timer?.cancel();
    _startForegroundTimer();
  }

  Future<void> _maybeRefresh(int intervalHours) async {
    final now = DateTime.now();
    if (_lastRefresh != null &&
        now.difference(_lastRefresh!).inHours < intervalHours) {
      return;
    }
    await checkNow();
  }

  // Android/iOS: workmanager periodic task
  void _rescheduleBackgroundTask() {
    if (!settings.library.autoRefresh.enabled.value) {
      _cancelBackgroundTask();
      return;
    }
    final intervalHours = settings.library.autoRefresh.interval.value;
    Workmanager().registerPeriodicTask(
      _taskName,
      _taskName,
      frequency: Duration(hours: intervalHours),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
    logger.i('Scheduled auto-refresh task every $intervalHours hours');
  }

  void _cancelBackgroundTask() {
    Workmanager().cancelByUniqueName(_taskName);
    logger.i('Cancelled auto-refresh task');
  }

  /// Trigger a refresh check from the foreground (e.g. manual button).
  Future<List<RefreshResult>> checkNow() async {
    logger.i('Starting auto-refresh check...');
    _lastRefresh = DateTime.now();
    final results = await performRefresh(
      shouldNotify: settings.library.autoRefresh.notify.value,
    );
    logger.i('Auto-refresh complete. ${results.length} entries updated.');
    return results;
  }

  /// Core refresh logic shared between foreground and background execution.
  ///
  /// [shouldNotify] controls whether local notifications are sent for entries
  /// with new episodes. When null, it falls back to the persisted preference.
  /// In a background isolate the global [settings] object may not be
  /// initialized, so callers in that context should read the preference
  /// directly and pass the value explicitly.
  static Future<List<RefreshResult>> performRefresh({
    bool? shouldNotify,
  }) async {
    final db = locate<Database>();
    final notify = shouldNotify ?? settings.library.autoRefresh.notify.value;

    final allEntries = await _getAllEntries(db);

    final candidates = allEntries.where((entry) {
      return entry.status == rust.ReleaseStatus.releasing &&
          entry.latestEpisode == entry.totalEpisodes;
    }).toList();

    logger.i('Found ${candidates.length} entries to check for updates');

    final updated = <RefreshResult>[];

    for (final entry in candidates) {
      try {
        final previousCount = entry.totalEpisodes;
        await entry.refresh();
        final newCount = entry.totalEpisodes;

        if (newCount > previousCount) {
          logger.i(
            '"${entry.title}" updated: $previousCount → $newCount episodes',
          );
          updated.add(
            RefreshResult(entry: entry, previousCount: previousCount),
          );
        }
      } catch (e, stack) {
        logger.e(
          'Failed to refresh "${entry.title}"',
          error: e,
          stackTrace: stack,
        );
      }

      await Future.delayed(_refreshDelay);
    }

    if (notify && updated.isNotEmpty) {
      await _sendNotifications(updated);
    }

    return updated;
  }

  static Future<List<EntrySaved>> _getAllEntries(Database db) async {
    final entries = <EntrySaved>[];
    const maxPages = 200;

    for (var page = 0; page < maxPages; page++) {
      final pageEntries = await db.getEntries(page, _pageSize).toList();
      entries.addAll(pageEntries);
      if (pageEntries.length < _pageSize) break;
    }

    return entries;
  }

  static Future<void> _sendNotifications(List<RefreshResult> updated) async {
    try {
      final notifService = locate<NotificationService>();

      if (updated.length == 1) {
        final r = updated.first;
        await notifService.showNewEpisodes(
          title: r.entry.title,
          previousCount: r.previousCount,
          newCount: r.entry.totalEpisodes,
          id: r.entry.title.hashCode,
        );
      } else {
        await notifService.showSummary(
          totalEntries: updated.length,
          titles: updated.map((e) => e.entry.title).toList(),
        );
      }
    } catch (e, stack) {
      logger.e('Failed to send notifications', error: e, stackTrace: stack);
    }
  }

  void dispose() {
    _timer?.cancel();
    settings.library.autoRefresh.enabled.removeListener(_onSettingsChanged);
    settings.library.autoRefresh.interval.removeListener(_onSettingsChanged);
  }
}

/// Result of a single entry refresh that found new episodes.
class RefreshResult {
  final EntrySaved entry;
  final int previousCount;

  const RefreshResult({required this.entry, required this.previousCount});
}

/// Top-level callback dispatcher for workmanager.
/// Must be a top-level function and is passed to [Workmanager.initialize] in
/// main.dart.
@pragma('vm:entry-point')
void autoRefreshCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != _taskName) return false;

    logger.i('Auto-refresh background task started');

    try {
      await PreferenceService.ensureInitialized();
      await DirectoryProvider.ensureInitialized();
      await Database.ensureInitialized();
      await ExtensionService.ensureInitialized();
      await NotificationService.ensureInitialized();

      // Read preference directly instead of relying on the global [settings]
      // object, which may not be initialized in this background isolate.
      final prefs = locate<PreferenceService>();
      final shouldNotify = prefs.getString('library.autorefresh.notify') == 'true';

      final results = await AutoRefreshService.performRefresh(
        shouldNotify: shouldNotify,
      );
      logger.i(
        'Auto-refresh background task complete: ${results.length} updates',
      );
      return true;
    } catch (e, stack) {
      logger.e(
        'Auto-refresh background task failed',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  });
}
