import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/views/activity/insights/insight_card.dart';
import 'package:dionysos/views/activity/insights/insight_widgets.dart';
import 'package:flutter/material.dart';

class OnRepeatData {
  final Entry entry;
  final Duration duration;

  /// [duration] as a share of all measured time in the window.
  final double share;
  final int sessions;

  const OnRepeatData({
    required this.entry,
    required this.duration,
    required this.share,
    required this.sessions,
  });
}

/// The title that dominated the last 30 days.
class OnRepeatCard extends InsightCard<OnRepeatData> {
  const OnRepeatCard();

  @override
  String get id => 'onRepeat';

  @override
  String get label => 'On Repeat';

  @override
  IconData get icon => Icons.repeat;

  @override
  Future<OnRepeatData?> compute(InsightContext context) async {
    final since = context.now.subtract(const Duration(days: 30));
    final durationByUid = <String, Duration>{};
    final sessionsByUid = <String, int>{};
    final entryByUid = <String, Entry>{};
    var total = Duration.zero;
    for (final activity in context.activitiesSince(since)) {
      final uid = activity.entry.id.uid;
      durationByUid[uid] =
          (durationByUid[uid] ?? Duration.zero) + activity.duration;
      sessionsByUid[uid] = (sessionsByUid[uid] ?? 0) + 1;
      entryByUid[uid] ??= context.entryFor(activity);
      total += activity.duration;
    }
    if (durationByUid.isEmpty) return null;
    final MapEntry(key: uid, value: duration) = durationByUid.entries.reduce(
      (a, b) => b.value > a.value ? b : a,
    );
    final share = duration.inSeconds / total.inSeconds;
    // A favourite needs real time, repeat visits and a clear lead; otherwise
    // this is just "the thing you happened to open".
    if (duration < const Duration(hours: 1) ||
        sessionsByUid[uid]! < 3 ||
        share < 0.25) {
      return null;
    }
    return OnRepeatData(
      entry: entryByUid[uid]!,
      duration: duration,
      share: share,
      sessions: sessionsByUid[uid]!,
    );
  }

  @override
  Widget build(BuildContext context, OnRepeatData data) {
    return InsightCoverLayout(
      entry: data.entry,
      child: InsightBody(
        top: InsightHero(
          value: '${(data.share * 100).round()}%',
          unit: 'of your time',
          caption: 'in the last 30 days',
        ),
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.entry.title.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: InsightStyles.emphasis(context),
            ),
            Text(
              '${formatDurationCompact(data.duration)} · '
              '${data.sessions} ${pluralize(data.sessions, 'session')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: InsightStyles.label(context),
            ),
          ],
        ),
      ),
    );
  }
}
