import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/views/activity/insights/insight_card.dart';
import 'package:dionysos/views/activity/insights/insight_widgets.dart';
import 'package:flutter/material.dart';
import 'package:moment_dart/moment_dart.dart';

class DaysAsCoversData {
  /// The day the statistic was computed for, used to highlight the
  /// current day in the strip.
  final DateTime today;

  /// The last seven UTC days, oldest first, each with the entry most time
  /// was spent on (null when the day had no measured activity).
  final List<(DateTime day, Entry? entry)> days;

  const DaysAsCoversData({required this.today, required this.days});
}

class DaysAsCoversCard extends InsightCard<DaysAsCoversData> {
  const DaysAsCoversCard();

  @override
  String get id => 'daysAsCovers';

  @override
  String get label => 'Week in Covers';

  @override
  IconData get icon => Icons.grid_view;

  @override
  double get weight => 1.5;

  @override
  Future<DaysAsCoversData?> compute(InsightContext context) async {
    final today = context.today;
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final totals = <DateTime, Map<String, Duration>>{};
    final entryByUid = <String, Entry>{};
    for (final activity in context.activities) {
      final day = InsightContext.dayKeyOf(activity.time);
      if (!days.contains(day)) continue;
      final uid = activity.entry.id.uid;
      final perUid = totals.putIfAbsent(day, () => {});
      perUid[uid] = (perUid[uid] ?? Duration.zero) + activity.duration;
      entryByUid[uid] ??= context.entryFor(activity);
    }
    // Two active days make the strip read as a week, one is just a cover.
    if (totals.length < 2) return null;

    Entry? topOf(DateTime day) {
      final perUid = totals[day];
      if (perUid == null) return null;
      return entryByUid[perUid.entries
          .reduce((a, b) => b.value > a.value ? b : a)
          .key];
    }

    return DaysAsCoversData(
      today: today,
      days: [for (final day in days) (day, topOf(day))],
    );
  }

  @override
  Widget build(BuildContext context, DaysAsCoversData data) {
    final scheme = context.theme.colorScheme;
    final empty = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DionRadius.sm),
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
    );
    return Row(
      children: [
        for (final (day, entry) in data.days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: InsightAspectBox(
                        child: entry == null
                            ? empty
                            : InsightCover(entry: entry),
                      ),
                    ),
                  ),
                  const SizedBox(height: DionSpacing.xs),
                  Text(
                    Moment(day.toLocal()).format('dd'),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: InsightStyles.axis(context).copyWith(
                      fontWeight: day == data.today
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: day == data.today
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
