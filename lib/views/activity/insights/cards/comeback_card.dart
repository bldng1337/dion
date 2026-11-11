import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/views/activity/insights/insight_card.dart';
import 'package:dionysos/views/activity/insights/insight_widgets.dart';
import 'package:flutter/material.dart';

class ComebackData {
  final Entry entry;

  /// Days between the two sessions on [entry] with the longest pause.
  final int gapDays;
  final DateTime returnedOn;

  const ComebackData({
    required this.entry,
    required this.gapDays,
    required this.returnedOn,
  });
}

class ComebackCard extends InsightCard<ComebackData> {
  const ComebackCard();

  @override
  String get id => 'comeback';

  @override
  String get label => 'Comeback';

  @override
  IconData get icon => Icons.replay;

  @override
  Future<ComebackData?> compute(InsightContext context) async {
    // Distinct active days per entry, then the largest gap between
    // consecutive days.
    final daysByUid = <String, Set<DateTime>>{};
    final entryByUid = <String, Entry>{};
    for (final activity in context.activities) {
      final uid = activity.entry.id.uid;
      daysByUid
          .putIfAbsent(uid, () => {})
          .add(InsightContext.dayKeyOf(activity.time));
      entryByUid[uid] ??= context.entryFor(activity);
    }

    String? topUid;
    var topGap = 0;
    DateTime? topReturn;
    for (final MapEntry(key: uid, value: days) in daysByUid.entries) {
      if (days.length < 2) continue;
      final sorted = days.toList()..sort();
      for (var i = 1; i < sorted.length; i++) {
        final gap = sorted[i].difference(sorted[i - 1]).inDays;
        if (gap > topGap) {
          topGap = gap;
          topUid = uid;
          topReturn = sorted[i];
        }
      }
    }
    // Anything under a week is just a normal pause, not a comeback.
    if (topUid == null || topReturn == null || topGap < 7) return null;
    return ComebackData(
      entry: entryByUid[topUid]!,
      gapDays: topGap,
      returnedOn: topReturn,
    );
  }

  @override
  Widget build(BuildContext context, ComebackData data) {
    return InsightCoverLayout(
      entry: data.entry,
      child: InsightBody(
        top: InsightHero(
          value: '${data.gapDays}',
          unit: 'days',
          caption: 'away before coming back',
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
              'Picked back up ${_on(formatDayLabel(data.returnedOn))}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: InsightStyles.label(context),
            ),
          ],
        ),
      ),
    );
  }

  String _on(String dayLabel) => switch (dayLabel) {
    'Today' || 'Yesterday' => dayLabel.toLowerCase(),
    _ => 'on $dayLabel',
  };
}
