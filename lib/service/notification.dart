import 'dart:io';

import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/platform.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const _channelId = 'entries_update';
const _channelName = 'Entry Updates';
const _channelDescription = 'Notifications for new episode updates';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

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
    final settings = InitializationSettings(
      android: androidSettings,
      linux: linuxSettings,
      windows: windowsSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    if (Platform.isAndroid) {
      await _requestAndroidPermissions();
      await _createAndroidChannel();
    }
  }

  Future<void> _requestAndroidPermissions() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;
    await androidPlugin.requestNotificationsPermission();
  }

  Future<void> _createAndroidChannel() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.defaultImportance,
    );
    await androidPlugin.createNotificationChannel(channel);
  }

  void _onNotificationResponse(NotificationResponse response) {
    // Could navigate to the specific entry detail in the future
    logger.d('Notification tapped: ${response.payload}');
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
    final body = '$diff new episode${diff == 1 ? '' : 's'} available '
        '($previousCount → $newCount)';

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(id, title, body, notificationDetails);
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
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      styleInformation: InboxStyleInformation(
        titles,
        contentTitle: 'Library Updates',
        summaryText: '$totalEntries entries updated',
      ),
    );
    final notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(0, 'Library Updates', body, notificationDetails);
    logger.i('Shown summary notification: $body');
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  bool _isPlatformSupported() {
    final platform = getPlatform();
    return platform == CPlatform.android ||
        platform == CPlatform.ios ||
        platform == CPlatform.macos;
  }
}