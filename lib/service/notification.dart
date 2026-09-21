import 'dart:io';

import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/platform.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const _channelId = 'entries_update';
const _channelName = 'Entry Updates';
const _channelDescription = 'Notifications for new episode updates';

const taskChannelId = 'task_progress';
const taskChannelName = 'Task Progress';
const taskChannelDescription =
    'Shown while downloads or other tasks are running';

const jobChannelId = 'periodic_jobs';
const jobChannelName = 'Background Jobs';
const jobChannelDescription = 'Progress of periodic library maintenance jobs';

// Windows progress notifications are shown once and then updated in place
// through data bindings, so progress ticks do not re-raise a toast every
// time. If the toast is gone (dismissed or aged out) the update reports
// notFound and the notification is re-shown on the next tick.
const _windowsProgressId = 'progress';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final _windowsProgressNotifications = <int>{};

  static Future<void> ensureInitialized() async {
    final service = NotificationService();
    await service.init();
    register<NotificationService>(service);
    logger.i('Initialised NotificationService!');
  }

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open',
    );
    const windowsSettings = WindowsInitializationSettings(
      appName: 'dion',
      appUserModelId: 'bldng.dion',
      guid: '79666d46-1ad2-5190-9e30-fb4f1f0e093a',
    );
    const settings = InitializationSettings(
      android: androidSettings,
      linux: linuxSettings,
      windows: windowsSettings,
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    if (Platform.isAndroid) {
      await _requestAndroidPermissions();
      await _createAndroidChannels();
    }
  }

  Future<void> _requestAndroidPermissions() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return;
    try {
      await androidPlugin.requestNotificationsPermission();
    } catch (e, stack) {
      logger.w(
        'Notification permission request skipped',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> _createAndroidChannels() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return;
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
      ),
    );
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        taskChannelId,
        taskChannelName,
        description: taskChannelDescription,
      ),
    );
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        jobChannelId,
        jobChannelName,
        description: jobChannelDescription,
      ),
    );
  }

  void _onNotificationResponse(NotificationResponse response) {
    // Could navigate to the specific entry detail in the future
    logger.d('Notification tapped: ${response.payload}');
  }

  /// Shows or updates a progress notification. Repeated calls with the same
  /// [id] update the existing notification instead of raising a new one;
  /// [progress] in 0..1, or null for an indeterminate bar.
  Future<void> showProgressNotification({
    required int id,
    required String channelId,
    required String channelName,
    required String channelDescription,
    required String title,
    required String body,
    double? progress,
  }) async {
    if (!_isPlatformSupported()) {
      logger.d('Notifications not supported on this platform');
      return;
    }
    try {
      if (Platform.isWindows) {
        await _showWindowsProgress(
          id: id,
          title: title,
          body: body,
          progress: progress,
        );
        return;
      }
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        ongoing: true,
        onlyAlertOnce: true,
        showProgress: true,
        indeterminate: progress == null,
        maxProgress: 100,
        progress: progress == null ? 0 : (progress.clamp(0, 1) * 100).round(),
      );
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: androidDetails,
          iOS: const DarwinNotificationDetails(
            presentSound: false,
            presentBanner: true,
          ),
        ),
      );
    } catch (e, stack) {
      logger.w('Progress notification failed', error: e, stackTrace: stack);
    }
  }

  Future<void> _showWindowsProgress({
    required int id,
    required String title,
    required String body,
    required double? progress,
  }) async {
    final progressBar = WindowsProgressBar(
      id: _windowsProgressId,
      status: body,
      value: progress?.clamp(0.0, 1.0),
    );
    if (_windowsProgressNotifications.contains(id)) {
      final windows = _plugin
          .resolvePlatformSpecificImplementation<
            FlutterLocalNotificationsWindows
          >();
      final result = await windows?.updateProgressBar(
        notificationId: id,
        progressBar: progressBar,
      );
      if (result == NotificationUpdateResult.success) return;
      _windowsProgressNotifications.remove(id);
    }
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        windows: WindowsNotificationDetails(progressBars: [progressBar]),
      ),
    );
    _windowsProgressNotifications.add(id);
  }

  Future<void> cancelNotification(int id) async {
    _windowsProgressNotifications.remove(id);
    if (!_isPlatformSupported()) return;
    try {
      await _plugin.cancel(id: id);
    } catch (e, stack) {
      logger.w('Cancelling notification failed', error: e, stackTrace: stack);
    }
  }

  Future<void> showNewEpisodes({
    required String title,
    required int previousCount,
    required int newCount,
    int id = 0,
  }) async {
    if (!_isPlatformSupported()) {
      logger.d('Notifications not supported on this platform');
      return;
    }

    final diff = newCount - previousCount;
    final body =
        '$diff new episode${diff == 1 ? '' : 's'} available '
        '($previousCount → $newCount)';

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
    logger.i('Shown notification for "$title": $body');
  }

  Future<void> showSummary({
    required int totalEntries,
    required List<String> titles,
  }) async {
    if (!_isPlatformSupported()) {
      logger.d('Notifications not supported on this platform');
      return;
    }

    final body = totalEntries == 1
        ? '${titles.first} has new episodes'
        : '$totalEntries entries have new episodes';

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      styleInformation: InboxStyleInformation(
        titles,
        contentTitle: 'Library Updates',
        summaryText: '$totalEntries entries updated',
      ),
    );
    final notificationDetails = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: 0,
      title: 'Library Updates',
      body: body,
      notificationDetails: notificationDetails,
    );
    logger.i('Shown summary notification: $body');
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  bool _isPlatformSupported() {
    final platform = getPlatform();
    return platform == CPlatform.android ||
        platform == CPlatform.ios ||
        platform == CPlatform.macos ||
        platform == CPlatform.windows;
  }
}
