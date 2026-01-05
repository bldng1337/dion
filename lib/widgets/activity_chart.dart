import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/utils/time.dart';
import 'package:flutter/material.dart'
    show BorderRadius, BoxDecoration, Colors, Tooltip;
import 'package:flutter/widgets.dart';
import 'package:moment_dart/moment_dart.dart';

class ActivityChart extends StatelessWidget {
  final Map<DateTime, Duration> activityData;
  final int weeks;
  final int daysPerWeek;

  const ActivityChart({
    super.key,
    required this.activityData,
    this.weeks = 52,
    this.daysPerWeek = 7,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity History',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          _buildChart(context),
          const SizedBox(height: 12),
          _buildLegend(context),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    final now = DateTime.now().toUtc().startOfDay();
    final startDate = now.subtract(Duration(days: weeks * daysPerWeek));

    final startOffset = daysPerWeek - startDate.weekday;
    final chartStartDate = startDate.add(Duration(days: startOffset));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_buildGrid(context, chartStartDate)],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, DateTime chartStartDate) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(weeks, (weekIndex) {
          return Column(
            children: List.generate(daysPerWeek, (dayIndex) {
              final date = chartStartDate.add(
                Duration(days: weekIndex * daysPerWeek + dayIndex),
              );
              final duration = activityData[date];
              return _buildCell(context, date, duration);
            }),
          );
        }),
      ),
    );
  }

  Widget _buildCell(BuildContext context, DateTime date, Duration? duration) {
    final color = _getColorForDuration(context, duration);
    final isFuture = date.isAfter(DateTime.now().toUtc());
    if (duration == null) {
      return Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: isFuture
              ? context.theme.colorScheme.surfaceContainerHighest
              : color,
          borderRadius: BorderRadius.circular(2),
        ),
      ).paddingAll(1);
    }
    if (isFuture) {
      return Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: context.theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(2),
        ),
      ).paddingAll(1);
    }
    return Tooltip(
      message: isFuture
          ? 'Future'
          : '${date.toLocal().toDateString()}\n${duration.formatrelative()}',
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ).paddingAll(1);
  }

  Color _getColorForDuration(BuildContext context, Duration? duration) {
    if (duration == null) {
      return context.theme.disabledColor.withValues(alpha: 0.03);
    }
    final theme = context.theme.colorScheme;

    // Define intensity thresholds (in seconds)
    const thresholds = <Duration>[
      Duration.zero,
      Duration(minutes: 30),
      Duration(hours: 1, minutes: 30),
      Duration(hours: 3),
    ];

    // Define opacity levels based on thresholds
    final opacities = <double>[
      0.15, // No activity
      0.25, // Low activity
      0.50, // Medium activity
      0.75, // High activity
      1.0, // Very high activity
    ];

    int level = 0;
    for (int i = 0; i < thresholds.length; i++) {
      if (duration > thresholds[i]) {
        level = i + 1;
      }
    }

    return theme.primary.withValues(alpha: opacities[level]);
  }

  Widget _buildLegend(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24),
      child: Row(
        children: [
          Text(
            'Less',
            style: context.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: context.theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(width: 8),
          ...List.generate(5, (index) {
            final theme = context.theme.colorScheme;
            final opacities = [0.08, 0.25, 0.50, 0.75, 1.0];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: theme.primary.withValues(alpha: opacities[index]),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
          const SizedBox(width: 8),
          Text(
            'More',
            style: context.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: context.theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
