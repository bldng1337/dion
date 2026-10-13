import 'package:dionysos/data/activity/episode.dart';
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/media_type.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter/material.dart';

/// How far back per-session cards look. Daily aggregates (streaks, weekday
/// habits) use their own longer window via [InsightContext.dailyTotals].
const insightActivityWindow = Duration(days: 180);

/// Shared, preloaded data every insight card computes from. Loaded once per
/// section build so N cards cost a constant number of queries instead of 2N.
class InsightContext {
  /// Local "now" at load time; cards must read it instead of calling
  /// `DateTime.now()` so a rebuild never changes the numbers mid-frame.
  final DateTime now;

  /// Sessions with measured time in the last [insightActivityWindow],
  /// ordered by time ascending.
  final List<EpisodeActivity> activities;

  /// UTC-midnight day keys to total measured time, last 365 days.
  final Map<DateTime, Duration> dailyTotals;

  /// Resolved entry per activity entry uid: saved library row when present,
  /// activity payload snapshot otherwise.
  final Map<String, Entry> entriesByUid;

  const InsightContext({
    required this.now,
    required this.activities,
    required this.dailyTotals,
    required this.entriesByUid,
  });

  static Future<InsightContext> load() async {
    final db = locate<Database>();
    final now = DateTime.now();
    // The 180-day window scan and the daily aggregate are independent; the
    // entry resolution below needs the activities, so only the first two
    // run concurrently.
    final (rawActivities, dailyTotals) = await (
      db.getActivitiesBetween(
        now.subtract(insightActivityWindow),
        now.add(const Duration(days: 1)),
      ),
      db.getDailyActivityDurations(),
    ).wait;
    final activities = rawActivities.whereType<EpisodeActivity>().toList()
      ..removeWhere((a) => a.duration <= Duration.zero)
      ..sort((a, b) => a.time.compareTo(b.time));
    final entries = await db.resolveActivityEntries(activities);
    return InsightContext(
      now: now,
      activities: activities,
      dailyTotals: dailyTotals,
      entriesByUid: entries,
    );
  }

  /// UTC-midnight key of a point in time, matching how [dailyTotals] and the
  /// heatmap group days.
  static DateTime dayKeyOf(DateTime time) {
    final utc = time.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day);
  }

  /// Monday on or before [time]'s UTC day.
  static DateTime weekStartOf(DateTime time) {
    final day = dayKeyOf(time);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  Duration totalIn(DateTime start, DateTime end) {
    var total = Duration.zero;
    for (final activity in activities) {
      if (!activity.time.isBefore(start) && activity.time.isBefore(end)) {
        total += activity.duration;
      }
    }
    return total;
  }

  /// Measured time per media verb ("Listened", "Read", ...) in [start, end).
  /// Comics and books share the "Read" verb, so a two-segment bar covers the
  /// common cases.
  Map<String, Duration> verbsIn(DateTime start, DateTime end) {
    final byVerb = <String, Duration>{};
    for (final activity in activities) {
      if (!activity.time.isBefore(start) && activity.time.isBefore(end)) {
        final verb = activity.entry.mediaType.activityVerb;
        byVerb[verb] = (byVerb[verb] ?? Duration.zero) + activity.duration;
      }
    }
    return byVerb;
  }
}

/// One insight card type. [compute] turns the shared [InsightContext] into
/// the card's statistic, returning null when there is not enough data to say
/// anything interesting; [build] renders it. Adding a card type is one class
/// plus one line in `registry.dart`.
abstract class InsightCard<T> {
  const InsightCard();

  String get id;

  /// Small uppercase header shown on the card chrome.
  String get label;

  IconData get icon;

  /// Relative chance of being drawn in the daily selection.
  double get weight => 1;

  /// Returns null when the statistic is not applicable (not enough data,
  /// nothing notable to say).
  Future<T?> compute(InsightContext context);

  Widget build(BuildContext context, T data);
}

/// A card that survived the applicability check, paired with its typed
/// statistic so [InsightCard.build] can be invoked without casts at the
/// call site.
@immutable
class InsightSelection<T> {
  final InsightCard<T> card;
  final T data;

  const InsightSelection(this.card, this.data);
}
