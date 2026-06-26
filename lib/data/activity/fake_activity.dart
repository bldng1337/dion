import 'dart:math';

import 'package:dionysos/data/activity/activity.dart';
import 'package:dionysos/data/activity/episode.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/extension.dart' hide TextStyle;
import 'package:dionysos/service/task.dart';
import 'package:dionysos/utils/service.dart';
import 'package:uuid/uuid.dart';

typedef _ProgressCallback = void Function(double progress, String status);

/// Generates randomized, intentionally non-uniform [EpisodeActivity] data over
/// the past [days] for every entry currently saved in the library.
///
/// The distribution is designed to resemble real listening/reading/watching
/// behaviour so the activity view can be tested realistically:
///
/// * A few entries are heavily used "favourites" while most are sparse or
///   untouched (popularity is drawn from a power distribution).
/// * Activity arrives in clustered bursts spread across a few "active
///   periods" (binge sessions) rather than evenly over time.
/// * Slightly more activity lands on weekends and in the evening.
/// * Durations vary per media type and scale with the number of episodes
///   consumed in a single session.
///
/// [onProgress] (if given) is invoked with values in `0..1` as entries are
/// processed, making it usable from a progress-reporting task.
Future<int> _generateFakeActivity({
  int days = 365,
  required Random rnd,
  required Uuid uuid,
  required List<EntrySaved> entries,
  bool Function()? shouldCancel,
  _ProgressCallback? onProgress,
}) async {
  final now = DateTime.now();
  final db = locate<Database>();
  var count = 0;

  for (var i = 0; i < entries.length; i++) {
    if (shouldCancel != null && shouldCancel()) break;
    final entry = entries[i];

    // Skew popularity toward 0 so most entries get little activity while a
    // handful become "favourites". pow(x, 3) heavily favours small values.
    final popularity = pow(rnd.nextDouble(), 3.0);

    // ~30% of low-popularity entries get no activity at all.
    if (popularity < 0.15 && rnd.nextDouble() > 0.3) {
      onProgress?.call((i + 1) / entries.length, 'Skipped "${entry.title}"');
      continue;
    }

    final totalSessions = (popularity * 80).round();
    if (totalSessions <= 0) {
      onProgress?.call((i + 1) / entries.length, 'Skipped "${entry.title}"');
      continue;
    }

    onProgress?.call(
      i / entries.length,
      'Generating $totalSessions sessions for "${entry.title}"',
    );

    final maxEpisode = entry.totalEpisodes > 0
        ? entry.totalEpisodes
        : (5 + rnd.nextInt(30));

    // Spread sessions across a few "active periods" (binge clusters).
    final numPeriods = max(1, min(totalSessions ~/ 6, 8));
    final periods = List.generate(numPeriods, (_) {
      final startDay = rnd.nextInt(days);
      final length = 1 + rnd.nextInt(14);
      return (startDay: startDay, length: length);
    });

    var episodeCursor = rnd.nextInt(maxEpisode);
    final batch = <Activity>[];

    for (var s = 0; s < totalSessions; s++) {
      if (shouldCancel != null && shouldCancel()) break;
      final period = periods[rnd.nextInt(periods.length)];
      final dayOffset = period.startDay + rnd.nextInt(period.length);
      final day = now.subtract(Duration(days: dayOffset));

      final time = _biasedTimeOfDay(day, now, rnd);
      if (time == null || time.isAfter(now)) continue;

      // Occasionally binge several consecutive episodes in one go.
      final burstSize = rnd.nextDouble() < 0.4 ? 1 + rnd.nextInt(4) : 1;
      final fromEp = episodeCursor % maxEpisode;
      final toEp = (fromEp + burstSize - 1) % maxEpisode;
      episodeCursor = toEp + 1;

      final perEpisode = _durationSecondsForMediaType(entry.mediaType, rnd);
      final durationSeconds = perEpisode * burstSize;

      batch.add(
        EpisodeActivity(
          id: uuid.v4(),
          // Store 1-indexed episode numbers for nicer display.
          fromepisode: fromEp + 1,
          toepisode: toEp + 1,
          entry: entry,
          extensionid: entry.boundExtensionId,
          time: time,
          duration: Duration(seconds: durationSeconds),
        ),
      );
      count++;
    }

    if (batch.isNotEmpty) {
      await db.addActivities(batch);
    }
    onProgress?.call((i + 1) / entries.length, 'Done "${entry.title}"');
  }

  return count;
}

/// Convenience wrapper that loads library entries and runs the generator.
/// Returns the number of activities created.
Future<int> generateFakeActivity({int days = 365, Random? random}) async {
  final db = locate<Database>();
  final entries = await _allEntries(db);
  if (entries.isEmpty) return 0;
  return _generateFakeActivity(
    days: days,
    rnd: random ?? Random(),
    uuid: const Uuid(),
    entries: entries,
  );
}

Future<List<EntrySaved>> _allEntries(Database db) async {
  final entries = <EntrySaved>[];
  for (var page = 0; ; page++) {
    final batch = await db.getEntries(page, 100).toList();
    if (batch.isEmpty) break;
    entries.addAll(batch);
    if (batch.length < 100) break;
  }
  return entries;
}

/// Picks an hour of day biased toward evening leisure hours, with weekends
/// getting extra weight. Returns null when the resulting time would be in the
/// future (e.g. early evening today), so we avoid creating future-dated rows.
DateTime? _biasedTimeOfDay(DateTime day, DateTime now, Random rnd) {
  // Weekends (Sat=6, Sun=7) are a bit busier.
  final isWeekend =
      day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

  int hour;
  final roll = rnd.nextDouble();
  if (roll < (isWeekend ? 0.55 : 0.45)) {
    // Evening / prime time: 18:00 - 23:00
    hour = 18 + rnd.nextInt(6);
  } else if (roll < (isWeekend ? 0.8 : 0.75)) {
    // Afternoon: 12:00 - 17:00
    hour = 12 + rnd.nextInt(6);
  } else {
    // Late night / scattered: 0:00 - 11:00
    hour = rnd.nextInt(12);
  }

  final time = DateTime(
    day.year,
    day.month,
    day.day,
    hour,
    rnd.nextInt(60),
    rnd.nextInt(60),
  );
  if (time.isAfter(now)) return null;
  return time;
}

/// Typical duration (in seconds) of a single episode/chapter per media type,
/// with noise so values aren't uniform.
int _durationSecondsForMediaType(MediaType mediaType, Random rnd) {
  int baseSeconds;
  switch (mediaType) {
    case MediaType.audio:
    case MediaType.video:
      // 20 - 45 minutes
      baseSeconds = (20 + rnd.nextInt(26)) * 60;
      break;
    case MediaType.book:
    case MediaType.comic:
      // 10 - 40 minutes
      baseSeconds = (10 + rnd.nextInt(31)) * 60;
      break;
    default:
      baseSeconds = (15 + rnd.nextInt(16)) * 60;
  }
  // +/- 20% jitter
  final jitter = (baseSeconds * (rnd.nextDouble() * 0.4 - 0.2)).round();
  return max(60, baseSeconds + jitter);
}

/// A cancellable [Task] that runs the fake-activity generator while reporting
/// progress, suitable for enqueuing via the dev task manager.
class GenerateFakeActivityTask extends Task {
  bool canceled = false;
  final int days;

  GenerateFakeActivityTask({this.days = 365}) : super('Generate Fake Activity');

  @override
  Future<void> onCancel() async {
    canceled = true;
  }

  @override
  Future<void> onRun() async {
    final db = locate<Database>();
    final entries = await _allEntries(db);
    if (entries.isEmpty) {
      status = 'No library entries found';
      return;
    }
    final count = await _generateFakeActivity(
      days: days,
      rnd: Random(),
      uuid: const Uuid(),
      entries: entries,
      shouldCancel: () => canceled,
      onProgress: (p, s) {
        progress = p;
        status = s;
      },
    );
    progress = 1.0;
    status = canceled
        ? 'Cancelled ($count activities)'
        : 'Generated $count activities';
  }
}
