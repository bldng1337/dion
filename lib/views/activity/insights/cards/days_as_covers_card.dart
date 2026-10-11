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
    final today = InsightContext.dayKeyOf(context.now);
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final perDay = <DateTime, (String, Duration)>{};
    for (final activity in context.activities) {
      final day = InsightContext.dayKeyOf(activity.time);
      if (!days.contains(day)) continue;
      final uid = activity.entry.id.uid;
      final current = perDay[day];
      final total = (current?.$2 ?? Duration.zero) + activity.duration;
      // Equal totals keep the first entry seen for the day.
      if (current == null || total > current.$2) perDay[day] = (uid, total);
    }
    // Two active days make the strip read as a week, one is just a cover.
    if (perDay.length < 2) return null;

    return DaysAsCoversData(
      today: today,
      days: [
        for (final day in days)
          (
            day,
            perDay[day] == null ? null : context.entriesByUid[perDay[day]!.$1],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, DaysAsCoversData data) {
    return Row(
      children: [
        for (final (day, entry) in data.days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: entry == null
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                DionRadius.sm,
                              ),
                              border: Border.all(
                                color: context.theme.colorScheme.onSurface
                                    .withValues(alpha: 0.15),
                                width: 0.5,
                              ),
                            ),
                          )
                        : InsightCover.expand(entry: entry),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    Moment(day.toLocal()).format('dd'),
                    style: context.labelSmall?.copyWith(
                      fontSize: 9.5,
                      fontWeight: day == data.today
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: day == data.today
                          ? context.theme.colorScheme.onSurface
                          : context.theme.colorScheme.onSurfaceVariant,
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
