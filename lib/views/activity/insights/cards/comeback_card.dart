import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/views/activity/insights/insight_card.dart';
import 'package:dionysos/views/activity/insights/insight_widgets.dart';
import 'package:flutter/material.dart';

class ComebackData {
  final Entry entry;

  /// Days between the last two sessions on [entry].
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
    for (final activity in context.activities) {
      final uid = activity.entry.id.uid;
      daysByUid
          .putIfAbsent(uid, () => {})
          .add(InsightContext.dayKeyOf(activity.time));
    }

    String? topUid;
    var topGap = 0;
    var topReturn = DateTime.now();
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
    if (topUid == null || topGap < 7) return null;
    final entry = context.entriesByUid[topUid];
    if (entry == null) return null;
    return ComebackData(entry: entry, gapDays: topGap, returnedOn: topReturn);
  }

  @override
  Widget build(BuildContext context, ComebackData data) {
    return Row(
      children: [
        InsightCover(entry: data.entry, width: 72),
        const SizedBox(width: DionSpacing.md),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InsightHero(
                value: '${data.gapDays}',
                unit: 'days',
                caption: 'away before coming back',
              ),
              const Spacer(),
              Text(
                'You returned to ${data.entry.title.trim()} '
                'on ${formatDayLabel(data.returnedOn)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.labelSmall?.copyWith(
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
