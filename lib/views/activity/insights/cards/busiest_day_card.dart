import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/views/activity/insights/insight_card.dart';
import 'package:dionysos/views/activity/insights/insight_widgets.dart';
import 'package:flutter/material.dart';

class BusiestDayData {
  final DateTime day;
  final Duration total;
  final Entry? entry;
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
    for (final activity in context.activities) {
      final day = InsightContext.dayKeyOf(activity.time);
      byDay[day] = (byDay[day] ?? Duration.zero) + activity.duration;
      final perUid = byDayByUid.putIfAbsent(day, () => {});
      final uid = activity.entry.id.uid;
      perUid[uid] = (perUid[uid] ?? Duration.zero) + activity.duration;
    }
    if (byDay.isEmpty) return null;
    final day = byDay.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    // Below half an hour, "busiest" says nothing worth a card.
    if (byDay[day]! < const Duration(minutes: 30)) return null;

    final perUid = byDayByUid[day]!;
    var topUid = '';
    var topDuration = Duration.zero;
    for (final MapEntry(key: uid, :value) in perUid.entries) {
      if (value > topDuration) {
        topUid = uid;
        topDuration = value;
      }
    }
    return BusiestDayData(
      day: day,
      total: byDay[day]!,
      entry: context.entriesByUid[topUid],
      entryDuration: topDuration,
    );
  }

  @override
  Widget build(BuildContext context, BusiestDayData data) {
    return Row(
      children: [
        InsightCover(entry: data.entry, width: 86),
        const SizedBox(width: DionSpacing.md),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InsightHero(
                value: formatDurationCompact(data.total),
                caption: formatDayLabel(data.day),
              ),
              const Spacer(),
              Text(
                'Mostly ${data.entry?.title.trim() ?? 'unknown entry'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
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
