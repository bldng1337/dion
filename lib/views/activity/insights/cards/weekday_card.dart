import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/views/activity/insights/insight_card.dart';
import 'package:dionysos/views/activity/insights/insight_widgets.dart';
import 'package:flutter/material.dart';

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

class WeekdayData {
  /// Index into Monday-first order.
  final int topWeekday;
  final double share;
  final List<Duration> perWeekday;

  const WeekdayData({
    required this.topWeekday,
    required this.share,
    required this.perWeekday,
  });
}

class WeekdayCard extends InsightCard<WeekdayData> {
  const WeekdayCard();

  @override
  String get id => 'weekday';

  @override
  String get label => 'Heaviest Day';

  @override
  IconData get icon => Icons.bar_chart;

  @override
  double get weight => 0.75;

  @override
  Future<WeekdayData?> compute(InsightContext context) async {
    final perWeekday = List<Duration>.filled(7, Duration.zero);
    var activeDays = 0;
    var total = Duration.zero;
    for (final entry in context.dailyTotals.entries) {
      if (entry.value <= Duration.zero) continue;
      activeDays++;
      perWeekday[entry.key.weekday - 1] += entry.value;
      total += entry.value;
    }
    if (total < const Duration(hours: 2) || activeDays < 3) return null;

    var top = 0;
    for (var i = 1; i < 7; i++) {
      if (perWeekday[i] > perWeekday[top]) top = i;
    }
    return WeekdayData(
      topWeekday: top,
      share: perWeekday[top].inMicroseconds / total.inMicroseconds,
      perWeekday: perWeekday,
    );
  }

  @override
  Widget build(BuildContext context, WeekdayData data) {
    final scheme = context.theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_weekdayNames[data.topWeekday]} is your heaviest day — '
          '${(data.share * 100).round()}% of your time.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
            color: scheme.onSurface,
          ),
        ),
        const Spacer(),
        BarStrip(
          values: data.perWeekday,
          accent: scheme.primary,
          highlightFrom: data.topWeekday,
          highlightTo: data.topWeekday,
        ),
      ],
    );
  }
}
