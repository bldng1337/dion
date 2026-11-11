import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/views/activity/insights/insight_card.dart';
import 'package:dionysos/views/activity/insights/insight_widgets.dart';
import 'package:flutter/material.dart';

class StreakData {
  final int current;
  final int longest;
  final bool activeToday;

  /// Whether each of the last 30 days had activity, oldest first; the last
  /// element is today.
  final List<bool> recent;

  const StreakData({
    required this.current,
    required this.longest,
    required this.activeToday,
    required this.recent,
  });
}

class StreakCard extends InsightCard<StreakData> {
  const StreakCard();

  @override
  String get id => 'streak';

  @override
  String get label => 'Streak';

  @override
  IconData get icon => Icons.local_fire_department;

  @override
  Future<StreakData?> compute(InsightContext context) async {
    final activeDays = {
      for (final entry in context.dailyTotals.entries)
        if (entry.value > Duration.zero) entry.key,
    };
    if (activeDays.isEmpty) return null;

    final today = context.today;
    // Today not logged yet does not break a streak running through yesterday.
    var cursor = activeDays.contains(today)
        ? today
        : today.subtract(const Duration(days: 1));
    var current = 0;
    while (activeDays.contains(cursor)) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var longest = 0;
    var run = 0;
    DateTime? previous;
    final sorted = activeDays.toList()..sort();
    for (final day in sorted) {
      run = previous != null && day.difference(previous).inDays == 1
          ? run + 1
          : 1;
      if (run > longest) longest = run;
      previous = day;
    }

    return StreakData(
      current: current,
      longest: longest,
      activeToday: activeDays.contains(today),
      recent: [
        for (var i = 29; i >= 0; i--)
          activeDays.contains(today.subtract(Duration(days: i))),
      ],
    );
  }

  @override
  Widget build(BuildContext context, StreakData data) {
    final running = data.current > 0;
    final leading = running ? data.current : data.longest;
    final caption = !running
        ? 'longest streak'
        : data.activeToday
        ? 'current streak'
        : 'current streak · keep it going today';
    final foot = running
        ? 'Longest: ${data.longest} ${pluralize(data.longest, 'day')}'
        : 'Do something today to start a new one';
    return InsightBody(
      top: InsightHero(
        value: '$leading',
        unit: pluralize(leading, 'day'),
        caption: caption,
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DayDots(days: data.recent, accent: context.theme.colorScheme.primary),
          const SizedBox(height: DionSpacing.xs + 2),
          Text(
            foot,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: InsightStyles.label(context),
          ),
        ],
      ),
    );
  }
}
