import 'dart:math' as math;

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/views/activity/insights/insight_card.dart';
import 'package:dionysos/views/activity/insights/insight_widgets.dart';
import 'package:flutter/material.dart';

class ConsistencyData {
  /// Measured time for the four calendar weeks ending this week, Monday
  /// first. Days after today are included as zero to keep the grid aligned.
  final List<Duration> days;

  /// Index of today in [days].
  final int todayIndex;
  final int activeDays;
  final Duration total;

  const ConsistencyData({
    required this.days,
    required this.todayIndex,
    required this.activeDays,
    required this.total,
  });

  int get elapsedDays => todayIndex + 1;
}

/// Active days over the last four calendar weeks, as a small grid.
class ConsistencyCard extends InsightCard<ConsistencyData> {
  const ConsistencyCard();

  @override
  String get id => 'consistency';

  @override
  String get label => 'Last 4 Weeks';

  @override
  IconData get icon => Icons.calendar_view_month;

  @override
  Future<ConsistencyData?> compute(InsightContext context) async {
    final start = InsightContext.weekStartOf(context.now)
        .subtract(const Duration(days: 21));
    final today = context.today;
    final days = [
      for (var i = 0; i < 28; i++)
        context.dailyTotals[start.add(Duration(days: i))] ?? Duration.zero,
    ];
    final todayIndex = today.difference(start).inDays.clamp(0, 27);
    var active = 0;
    var total = Duration.zero;
    for (var i = 0; i <= todayIndex; i++) {
      if (days[i] > Duration.zero) {
        active++;
        total += days[i];
      }
    }
    if (active < 3) return null;
    return ConsistencyData(
      days: days,
      todayIndex: todayIndex,
      activeDays: active,
      total: total,
    );
  }

  @override
  Widget build(BuildContext context, ConsistencyData data) {
    final average = Duration(seconds: data.total.inSeconds ~/ data.activeDays);
    return InsightAside(
      maxAsideFraction: 0.5,
      aside: _WeekGrid(data: data),
      child: InsightBody(
        top: InsightHero(
          value: '${data.activeDays}',
          unit: 'of ${data.elapsedDays} days',
          caption: 'with activity',
        ),
        bottom: Text(
          '${formatDurationCompact(average)} on an average active day',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: InsightStyles.label(context),
        ),
      ),
    );
  }
}

class _WeekGrid extends StatelessWidget {
  final ConsistencyData data;

  const _WeekGrid({required this.data});

  static const _gap = 3.0;
  static const _maxCell = 22.0;

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    final maxSeconds = data.days.fold<int>(
      0,
      (max, day) => math.max(max, day.inSeconds),
    );
    Color colorOf(int index) {
      final seconds = data.days[index].inSeconds;
      if (index > data.todayIndex) return Colors.transparent;
      if (seconds <= 0 || maxSeconds <= 0) {
        return scheme.onSurfaceVariant.withValues(alpha: 0.12);
      }
      // Four steps read better than a continuous ramp at this size.
      final level = (seconds / maxSeconds * 4).ceil().clamp(1, 4);
      return scheme.primary.withValues(alpha: 0.25 + 0.75 * level / 4);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = math
            .min(
              _maxCell,
              math.min(
                (constraints.maxHeight - _gap * 3) / 4,
                (constraints.maxWidth - _gap * 6) / 7,
              ),
            )
            .floorToDouble();
        if (cell < 4) return const SizedBox.shrink();
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var week = 0; week < 4; week++) ...[
                if (week > 0) const SizedBox(height: _gap),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var weekday = 0; weekday < 7; weekday++) ...[
                      if (weekday > 0) const SizedBox(width: _gap),
                      Container(
                        width: cell,
                        height: cell,
                        decoration: BoxDecoration(
                          color: colorOf(week * 7 + weekday),
                          borderRadius: BorderRadius.circular(DionRadius.xs),
                          border: week * 7 + weekday == data.todayIndex
                              ? Border.all(color: scheme.onSurface)
                              : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
