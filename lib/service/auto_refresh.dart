import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/notification.dart';
import 'package:dionysos/service/periodic_service.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

const _refreshDelay = Duration(seconds: 2);

const _pageSize = 50;

class AutoRefreshJob extends PeriodicJob {
  @override
  String get taskName => 'autoRefreshEntries';

  @override
  String get displayName => 'Auto-refresh entries';

  @override
  Setting<bool, dynamic> get enabledSetting =>
      settings.library.autoRefresh.enabled;

  @override
  Setting<int, dynamic> get intervalSetting =>
      settings.library.autoRefresh.interval;

  @override
  Future<void> run() async {
    await performRefresh();
  }

  static Future<List<RefreshResult>> performRefresh() async {
    final db = locate<Database>();
    const maxPages = 400; // So we dont loop forever 400*50 = 20k these are more entries than anyone sane would have in their library

    final updated = <RefreshResult>[];

    for (var page = 0; page < maxPages; page++) {
      final pageEntries = await db.getEntries(page, _pageSize).toList();
      if (pageEntries.length < _pageSize) break;
      final candidates = pageEntries.where((entry) {
        return entry.status == rust.ReleaseStatus.releasing &&
            entry.latestEpisode == entry.totalEpisodes;
      }).toList();

      logger.i('Found ${candidates.length} entries to check for updates');

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
    }
    final notify = settings.library.autoRefresh.notify.value;
    if (notify && updated.isNotEmpty) {
      await _sendNotifications(updated);
    }

    return updated;
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
}

class RefreshResult {
  final EntrySaved entry;
  final int previousCount;

  const RefreshResult({required this.entry, required this.previousCount});
}
