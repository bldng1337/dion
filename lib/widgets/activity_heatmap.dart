import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:contribution_heatmap/contribution_heatmap.dart';
import 'package:dionysos/utils/time.dart';
import 'package:dionysos/widgets/container/container.dart';
import 'package:flutter/material.dart';
import 'package:moment_dart/moment_dart.dart';

class ActivityHeatmap extends StatelessWidget {
  final Map<DateTime, Duration> activityData;
  final int days;

  const ActivityHeatmap({
    super.key,
    required this.activityData,
    this.days = 364,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc().startOfDay();
    final minDate = now.subtract(Duration(days: days));
    final maxDate = now;

    final entries = activityData.entries
        .where((e) => e.value > Duration.zero)
        .map((e) => ContributionEntry(e.key, e.value.inSeconds))
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 53;
        const spacing = 3.0;
        const padX = 16.0;
        final available =
            constraints.maxWidth - padX * 2 - spacing * (columns - 1);
        final cellSize = available.isFinite && available > 0
            ? (available / columns).clamp(7.0, 16.0)
            : 11.0;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ContributionHeatmap(
            entries: entries,
            minDate: minDate,
            maxDate: maxDate,
            cellSize: cellSize,
            padding: const EdgeInsets.symmetric(horizontal: padX, vertical: 12),
            weekdayLabel: WeekdayLabel.githubLike,
            onCellTap: (date, value) => _showActivityInfo(context, date, value),
          ),
        );
      },
    );
  }

  void _showActivityInfo(BuildContext context, DateTime date, int value) {
    final duration = Duration(seconds: value);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          duration > Duration.zero
              ? '${Moment(date).format('LL')}: ${duration.formatrelative()}'
              : '${Moment(date).format('LL')}: No activity',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class ActivityHeatmapPanel extends StatelessWidget {
  final Map<DateTime, Duration> activityData;

  const ActivityHeatmapPanel({super.key, required this.activityData});

  @override
  Widget build(BuildContext context) {
    return DionContainer(
      color: context.theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Activity History',
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            ActivityHeatmap(activityData: activityData),
          ],
        ),
      ),
    );
  }
}
