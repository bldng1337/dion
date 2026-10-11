import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/views/activity/insights/insight_card.dart';
import 'package:dionysos/views/activity/insights/insight_widgets.dart';
import 'package:flutter/material.dart';

class StreakData {
  final int current;
  final int longest;
  final bool activeToday;

  const StreakData({
    required this.current,
    required this.longest,
    required this.activeToday,
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

    final today = InsightContext.dayKeyOf(context.now);
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
    );
  }

  @override
  Widget build(BuildContext context, StreakData data) {
    final leading = data.current > 0 ? data.current : data.longest;
    final caption = data.current > 0 ? 'current streak' : 'longest streak';
    final foot = data.current > 0
        ? 'Longest streak: ${data.longest} ${data.longest == 1 ? 'day' : 'days'}'
        : 'Do something today to start a new one';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InsightHero(
          value: '$leading',
          unit: leading == 1 ? 'day' : 'days',
          caption: caption,
        ),
        const Spacer(),
        Text(
          foot,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.labelMedium?.copyWith(
            color: context.theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
