import 'dart:io';

import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/service/auto_refresh.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/service/extension_updates.dart';
import 'package:dionysos/service/notification.dart';
import 'package:dionysos/service/preference.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/string.dart';
import 'package:workmanager/workmanager.dart';

String lastRunKey(String taskName) => '$taskName.lastrun';

abstract class PeriodicJob {
  String get taskName;

  String get displayName => taskName.humanized;

  Setting<bool, dynamic> get enabledSetting;
  Setting<int, dynamic> get intervalSetting;

  Future<void> run();

  Future<bool> runAndRecord() async {
    try {
      await run();
      await locate<PreferenceService>().setString(
        lastRunKey(taskName),
        DateTime.now().toIso8601String(),
      );
      return true;
    } catch (e, stack) {
      logger.e('PeriodicJob $taskName failed', error: e, stackTrace: stack);
      return false;
    }
  }
}

final Map<String, PeriodicJob> _jobs = {
  AutoRefreshJob().taskName: AutoRefreshJob(),
  ExtensionUpdateJob().taskName: ExtensionUpdateJob(),
};

class PeriodicService {
  // ignore: unreachable_from_main
  static Future<void> ensureInitialized() async {
    final service = PeriodicService();
    await service.init();
    register<PeriodicService>(service);
    logger.i('Initialised PeriodicService!');
  }

  Future<void> init() async {
    await locateAsync<PreferenceService>();
    for (final job in _jobs.values) {
      job.enabledSetting.addListener(_onSettingsChanged);
      job.intervalSetting.addListener(_onSettingsChanged);
      _reschedule(job);
    }
  }

  void _onSettingsChanged() {
    for (final job in _jobs.values) {
      _reschedule(job);
    }
  }

  Future<void> _reschedule(PeriodicJob job) async {
    if (Platform.isWindows) return;
    try {
      if (!job.enabledSetting.value) {
        await Workmanager().cancelByUniqueName(job.taskName);
        logger.i('Cancelled periodic task ${job.taskName}');
        return;
      }
      final intervalHours = job.intervalSetting.value;
      await Workmanager().registerPeriodicTask(
        job.taskName,
        job.taskName,
        frequency: Duration(hours: intervalHours),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
      logger.i(
        'Scheduled periodic task ${job.taskName} every $intervalHours hours',
      );
    } catch (e, stack) {
      logger.e(
        'Failed to reschedule periodic task ${job.taskName}',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Map<String, PeriodicJob> get jobs => Map.unmodifiable(_jobs);

  DateTime? lastRun(PeriodicJob job) {
    final raw = locate<PreferenceService>().getString(lastRunKey(job.taskName));
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }
}


Future<bool> seedBackgroundDependencies() async {
  try {
    await PreferenceService.ensureInitialized();
    await DirectoryProvider.ensureInitialized();
    await Database.ensureInitialized();
    await ExtensionService.ensureInitialized();
    await NotificationService.ensureInitialized();
    return true;
  } catch (e, stack) {
    logger.w(
      'Background dependency seeding failed; dismissing this run',
      error: e,
      stackTrace: stack,
    );
    return false;
  }
}

@pragma('vm:entry-point')
void backgroundTaskDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    logger.i('Background task dispatched: $task');

    if (!await seedBackgroundDependencies()) {
      return true;
    }

    final job = _jobs[task];
    if (job == null) {
      logger.w('No PeriodicJob registered for task $task');
      return false;
    }
    // runAndRecord runs the job and persists the last successful run time;
    // returns false (so Workmanager retries) if the job threw.
    final ok = await job.runAndRecord();
    logger.i('Background task $task ${ok ? 'complete' : 'failed'}');
    return ok;
  });
}
