import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/views/activity/insights/insight_card.dart';
import 'package:dionysos/views/activity/insights/insight_widgets.dart';
import 'package:flutter/material.dart';

class FreshPicksData {
  final int count;

  /// Time spent on the new titles since they were picked up.
  final Duration duration;

  /// Up to three of the new titles, most recently started first.
  final List<Entry> latest;

  const FreshPicksData({
    required this.count,
    required this.duration,
    required this.latest,
  });
}

/// Titles started in the last 30 days.
class FreshPicksCard extends InsightCard<FreshPicksData> {
  const FreshPicksCard();

  @override
  String get id => 'freshPicks';

  @override
  String get label => 'Fresh Picks';

  @override
  IconData get icon => Icons.auto_awesome;

  @override
  Future<FreshPicksData?> compute(InsightContext context) async {
    final cutoff = context.now.subtract(const Duration(days: 30));
    // Activities are ordered by time, so the first sighting of a uid is its
    // start. "New" can only mean new within the loaded window.
    final firstSeen = <String, DateTime>{};
    final entryByUid = <String, Entry>{};
    final durationByUid = <String, Duration>{};
    for (final activity in context.activities) {
      final uid = activity.entry.id.uid;
      firstSeen.putIfAbsent(uid, () => activity.time);
      entryByUid[uid] ??= context.entryFor(activity);
      durationByUid[uid] =
          (durationByUid[uid] ?? Duration.zero) + activity.duration;
    }
    final fresh = [
      for (final MapEntry(key: uid, value: start) in firstSeen.entries)
        if (!start.isBefore(cutoff)) uid,
    ]..sort((a, b) => firstSeen[b]!.compareTo(firstSeen[a]!));
    if (fresh.length < 2) return null;
    return FreshPicksData(
      count: fresh.length,
      duration: fresh.fold(
        Duration.zero,
        (sum, uid) => sum + durationByUid[uid]!,
      ),
      latest: [for (final uid in fresh.take(3)) entryByUid[uid]!],
    );
  }

  @override
  Widget build(BuildContext context, FreshPicksData data) {
    return InsightAside(
      aside: InsightCoverFan(entries: data.latest),
      child: InsightBody(
        top: InsightHero(
          value: '${data.count}',
          unit: pluralize(data.count, 'new title'),
          caption: 'started in the last 30 days',
        ),
        bottom: Text(
          '${formatDurationCompact(data.duration)} spent on them so far',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: InsightStyles.label(context),
        ),
      ),
    );
  }
}
