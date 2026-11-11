import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/views/activity/insights/insight_card.dart';
import 'package:dionysos/views/activity/insights/insight_widgets.dart';
import 'package:flutter/material.dart';

class BusiestDayData {
  final DateTime day;
  final Duration total;
  final Entry entry;
  final Duration entryDuration;

  const BusiestDayData({
    required this.day,
    required this.total,
    required this.entry,
    required this.entryDuration,
  });
}

class BusiestDayCard extends InsightCard<BusiestDayData> {
  const BusiestDayCard();

  @override
  String get id => 'busiestDay';

  @override
  String get label => 'Busiest Day';

  @override
  IconData get icon => Icons.event;

  @override
  double get weight => 1.5;

  @override
  Future<BusiestDayData?> compute(InsightContext context) async {
    // Per-day totals and per-day per-entry totals in one pass, all keyed by
    // UTC day so a session never crosses a grouping boundary.
    final byDay = <DateTime, Duration>{};
    final byDayByUid = <DateTime, Map<String, Duration>>{};
    final entryByUid = <String, Entry>{};
    for (final activity in context.activities) {
      final day = InsightContext.dayKeyOf(activity.time);
      byDay[day] = (byDay[day] ?? Duration.zero) + activity.duration;
      final perUid = byDayByUid.putIfAbsent(day, () => {});
      final uid = activity.entry.id.uid;
      perUid[uid] = (perUid[uid] ?? Duration.zero) + activity.duration;
      entryByUid[uid] ??= context.entryFor(activity);
    }
    if (byDay.isEmpty) return null;
    final day = byDay.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    // Below half an hour, "busiest" says nothing worth a card.
    if (byDay[day]! < const Duration(minutes: 30)) return null;

    final top = byDayByUid[day]!.entries.reduce(
      (a, b) => b.value > a.value ? b : a,
    );
    return BusiestDayData(
      day: day,
      total: byDay[day]!,
      entry: entryByUid[top.key]!,
      entryDuration: top.value,
    );
  }

  @override
  Widget build(BuildContext context, BusiestDayData data) {
    return InsightCoverLayout(
      entry: data.entry,
      child: InsightBody(
        top: InsightHero(
          value: formatDurationCompact(data.total),
          caption: formatDayLabel(data.day),
        ),
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.entry.title.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: InsightStyles.emphasis(context),
            ),
            Text(
              '${formatDurationCompact(data.entryDuration)} of it',
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
