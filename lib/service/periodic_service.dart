// This service is wired up from widget build methods and their closures
// (loading.dart's init task list and the periodic jobs settings view), which
// `unreachable_from_main` does not traverse, so it reports every member here
// as unreachable even though all of them are used.
// ignore_for_file: unreachable_from_main
import 'dart:async';
import 'dart:convert';
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
String lastErrorKey(String taskName) => '$taskName.lasterror';

class PeriodicJobContext {
  static const _minInterval = Duration(milliseconds: 500);

  final int _notificationId;
  final String displayName;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);

  PeriodicJobContext({required String taskName})
      : _notificationId = taskName.hashCode,
        displayName = taskName.humanized;

  /// Reports the current activity; [progress] in 0..1, or null to show an
  /// indeterminate bar.
  void update(String status, {double? progress}) {
    final now = DateTime.now();
    if (now.difference(_lastSent) < _minInterval) return;
    _lastSent = now;
    unawaited(_show(status, progress));
  }

  Future<void> _show(String status, double? progress) async {
    try {
      await locate<NotificationService>().showProgressNotification(
        id: _notificationId,
        channelId: jobChannelId,
        channelName: jobChannelName,
        channelDescription: jobChannelDescription,
        title: displayName,
        body: status,
        progress: progress,
      );
    } catch (e, stack) {
      logger.w(
        'Job progress notification failed',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> close() async {
    if (!has<NotificationService>()) return;
    try {
      await locate<NotificationService>().cancelNotification(_notificationId);
    } catch (e, stack) {
      logger.w(
        'Cancelling job progress notification failed',
        error: e,
        stackTrace: stack,
      );
    }
  }
}

/// Outcome of the last failed run of a [PeriodicJob], persisted so failures
/// from the background isolate surface in the running app.
class JobError {
  final DateTime time;
  final String message;

  const JobError({required this.time, required this.message});

  factory JobError.fromJson(Map<String, dynamic> json) => JobError(
        time: DateTime.parse(json['time'] as String),
        message: json['message'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'time': time.toIso8601String(), 'message': message};
}

abstract class PeriodicJob {
  String get taskName;

  String get displayName => taskName.humanized;

  Setting<bool, dynamic> get enabledSetting;
  Setting<int, dynamic> get intervalSetting;

  Future<void> run(PeriodicJobContext ctx);

  Future<bool> runAndRecord() async {
    final ctx = PeriodicJobContext(taskName: taskName);
    try {
      await run(ctx);
      final preferences = locate<PreferenceService>();
      await preferences.setString(
        lastRunKey(taskName),
        DateTime.now().toIso8601String(),
      );
      await preferences.remove(lastErrorKey(taskName));
      return true;
    } catch (e, stack) {
      logger.e('PeriodicJob $taskName failed', error: e, stackTrace: stack);
      await locate<PreferenceService>().setString(
        lastErrorKey(taskName),
        jsonEncode(
          JobError(time: DateTime.now(), message: e.toString()).toJson(),
        ),
      );
      return false;
    } finally {
      await ctx.close();
    }
  }
}

final Map<String, PeriodicJob> _jobs = {
  AutoRefreshJob().taskName: AutoRefreshJob(),
  ExtensionUpdateJob().taskName: ExtensionUpdateJob(),
};

class PeriodicService {
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
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
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

  JobError? lastError(PeriodicJob job) {
    final raw =
        locate<PreferenceService>().getString(lastErrorKey(job.taskName));
    if (raw == null) return null;
    try {
      return JobError.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
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
  // Tag everything logged from here on as background-origin so the log view
  // can distinguish periodic job output from main-isolate logs.
  LogStore.instance.source = kLogSourceBackground;
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
