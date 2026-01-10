import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/utils/platform.dart';
import 'package:dionysos/utils/time.dart';
import 'package:flutter/material.dart';
import 'package:moment_dart/moment_dart.dart';

class ActivityChart extends StatefulWidget {
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
  State<ActivityChart> createState() => _ActivityChartState();
}

class _ActivityChartState extends State<ActivityChart> {
  // Mechanism to track the currently active tooltip controller (for mobile mainly)
  _ChartCellState? _activeTooltip;

  void _onTooltipActivated(_ChartCellState cellState) {
    if (_activeTooltip != null && _activeTooltip != cellState) {
      _activeTooltip?._hideTooltip();
    }
    _activeTooltip = cellState;
  }

  void _handleTapOutside() {
    if (_activeTooltip != null) {
      _activeTooltip?._hideTooltip();
      _activeTooltip = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (event) {
        _handleTapOutside();
      },
      child: GestureDetector(
        onTap: () {
          _handleTapOutside();
        },
        behavior: HitTestBehavior.translucent,
        child: Padding(
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
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    final now = DateTime.now().toUtc().startOfDay();
    final startDate = now.subtract(Duration(days: widget.weeks * widget.daysPerWeek));

    final startOffset = widget.daysPerWeek - startDate.weekday;
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(widget.weeks, (weekIndex) {
          return Column(
            children: List.generate(widget.daysPerWeek, (dayIndex) {
              final date = chartStartDate.add(
                Duration(days: weekIndex * widget.daysPerWeek + dayIndex),
              );
              final duration = widget.activityData[date];
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

    return _ChartCell(
      date: date,
      duration: duration,
      color: color,
      onActivated: _onTooltipActivated,
    );
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

class _ChartCell extends StatefulWidget {
  final DateTime date;
  final Duration? duration;
  final Color color;
  final Function(_ChartCellState) onActivated;

  const _ChartCell({
    required this.date,
    required this.duration,
    required this.color,
    required this.onActivated,
  });

  @override
  State<_ChartCell> createState() => _ChartCellState();
}

class _ChartCellState extends State<_ChartCell> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  bool get isMobile =>
      getPlatform() == CPlatform.android || getPlatform() == CPlatform.ios;

  void _showTooltip() {
    if (_overlayEntry != null) return;

    // Notify parent that this cell is active
    widget.onActivated(this);

    final overlay = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) => CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.topCenter,
        followerAnchor: Alignment.bottomCenter,
        offset: const Offset(0, -6),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: _TooltipCard(
            date: widget.date,
            duration: widget.duration,
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);

    // Force rebuild to show highlight border
    if (mounted) setState(() {});
  }

  void _hideTooltip() {
    if (_overlayEntry == null) return;

    _overlayEntry?.remove();
    _overlayEntry = null;

    if (mounted) setState(() {});
  }

  void _toggleTooltip() {
    if (_overlayEntry != null) {
      _hideTooltip();
    } else {
      _showTooltip();
    }
  }

  @override
  void didUpdateWidget(_ChartCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date || oldWidget.duration != widget.duration) {
      if (_overlayEntry != null) {
        _hideTooltip();
      }
    }
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: isMobile ? null : (_) => _showTooltip(),
        onExit: isMobile ? null : (_) => _hideTooltip(),
        child: GestureDetector(
          onTap: isMobile ? _toggleTooltip : null,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(2),
              border: _overlayEntry != null
                  ? Border.all(
                      color: context.theme.colorScheme.onSurface,
                    )
                  : null,
            ),
          ).paddingAll(1),
        ),
      ),
    );
  }
}

class _TooltipCard extends StatelessWidget {
  final DateTime date;
  final Duration? duration;

  const _TooltipCard({required this.date, this.duration});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: context.theme.colorScheme.surfaceContainer,
      shadowColor: Colors.black45,
      type: MaterialType.card,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: context.theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              date.toDateString(),
              style: context.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            if (duration != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: context.theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    duration!.formatrelative(),
                    style: context.textTheme.bodySmall,
                  ),
                ],
              )
            else
              Text(
                'No activity',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
