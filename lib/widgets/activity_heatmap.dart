import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:contribution_heatmap/contribution_heatmap.dart';
import 'package:dionysos/utils/time.dart';
import 'package:dionysos/widgets/container/container.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:moment_dart/moment_dart.dart';

class ActivityHeatmap extends StatefulWidget {
  final Map<DateTime, Duration> activityData;
  final int days;

  const ActivityHeatmap({
    super.key,
    required this.activityData,
    this.days = 364,
  });

  @override
  State<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends State<ActivityHeatmap> {
  /// Key into the rendered heatmap so we can map a pointer position to a cell.
  final GlobalKey _heatmapKey = GlobalKey();

  /// Kind of the last pointer that went down. Used to distinguish touch
  /// (snackbar) from mouse/trackpad (hover tooltip).
  PointerDeviceKind? _pointerKind;

  /// Currently shown hover tooltip, if any.
  OverlayEntry? _tooltipEntry;

  /// The date the tooltip currently describes. Avoids rebuilding the overlay
  /// while the cursor moves within the same cell.
  DateTime? _hoveredDate;

  // Layout constants that must match the values passed to ContributionHeatmap.
  static const double _padX = 16.0;
  static const double _padY = 12.0;
  static const double _spacing = 3.0;

  @override
  void dispose() {
    _hideTooltip();
    super.dispose();
  }

  /// Normalizes a date to a UTC midnight key, matching the heatmap's internal
  /// indexing so lookups stay consistent regardless of input timezone.
  static DateTime _dayKey(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  /// Monday on or before [d] (the heatmap week-starts on Monday by default).
  static DateTime _alignToWeekStart(DateTime d) {
    var diff = d.weekday - DateTime.monday;
    if (diff < 0) diff += 7;
    return _dayKey(d).subtract(Duration(days: diff));
  }

  static DateTime _alignToWeekEnd(DateTime d) =>
      _alignToWeekStart(d).add(const Duration(days: 6));

  String _activityText(DateTime date, int value) {
    final duration = Duration(seconds: value);
    return duration > Duration.zero
        ? '${Moment(date).format('LL')}: ${duration.formatrelative()}'
        : '${Moment(date).format('LL')}: No activity';
  }

  /// Touch/tap path: show a floating snackbar. On non-touch devices hover is
  /// preferred, so we no-op here.
  void _showActivityInfo(DateTime date, int value) {
    if (_pointerKind != PointerDeviceKind.touch) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(_activityText(date, value)),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Resolves a global pointer position to the heatmap cell beneath it, or
  /// null when the pointer is over padding, labels, or the gaps between cells.
  ///
  /// The grid origin is derived from the heatmap's laid-out [RenderBox] size
  /// plus the known layout parameters, which keeps this in sync with the
  /// package's painting without replicating its text-measurement code.
  ({DateTime date, int value})? _cellAtPosition(
    Offset globalPosition,
    double cellSize,
    DateTime firstDay,
    int totalColumns,
    int sequenceLength,
    Map<DateTime, int> valueByDate,
  ) {
    final box = _heatmapKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final local = box.globalToLocal(globalPosition);

    final gridWidth = totalColumns * cellSize + (totalColumns - 1) * _spacing;
    final gridHeight = 7 * cellSize + 6 * _spacing;
    final gridLeft = box.size.width - gridWidth - _padX;
    final gridTop = box.size.height - gridHeight - _padY;

    final gridX = local.dx - gridLeft;
    final gridY = local.dy - gridTop;
    if (gridX < 0 || gridY < 0) return null;

    final pitch = cellSize + _spacing;
    final column = gridX ~/ pitch;
    final row = gridY ~/ pitch;
    if (column < 0 || column >= totalColumns || row < 0 || row >= 7) {
      return null;
    }
    // Inside the spacing gutter between cells, not on a cell.
    if (gridX - column * pitch > cellSize || gridY - row * pitch > cellSize) {
      return null;
    }

    final index = column * 7 + row;
    if (index >= sequenceLength) return null;

    final date = firstDay.add(Duration(days: index));
    return (date: date, value: valueByDate[_dayKey(date)] ?? 0);
  }

  void _handleHover(
    PointerHoverEvent event,
    double cellSize,
    DateTime firstDay,
    int totalColumns,
    int sequenceLength,
    Map<DateTime, int> valueByDate,
  ) {
    if (!mounted) return;
    final cell = _cellAtPosition(
      event.position,
      cellSize,
      firstDay,
      totalColumns,
      sequenceLength,
      valueByDate,
    );

    if (cell == null) {
      _hideTooltip();
      return;
    }
    // Same cell as before: keep the tooltip where it is to avoid jitter.
    if (_hoveredDate == cell.date && _tooltipEntry != null) return;

    _hoveredDate = cell.date;
    _tooltipEntry?.remove();
    _tooltipEntry = OverlayEntry(
      builder: (_) => _ActivityTooltip(
        globalPosition: event.position,
        message: _activityText(cell.date, cell.value),
      ),
    );
    Overlay.of(context).insert(_tooltipEntry!);
  }

  void _hideTooltip() {
    _hoveredDate = null;
    _tooltipEntry?.remove();
    _tooltipEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc().startOfDay();
    final minDate = now.subtract(Duration(days: widget.days));
    final maxDate = now;

    final firstDay = _alignToWeekStart(minDate);
    final lastDay = _alignToWeekEnd(maxDate);
    final sequenceLength = lastDay.difference(firstDay).inDays + 1;
    final totalColumns = (sequenceLength / 7).ceil();

    final entries = widget.activityData.entries
        .where((e) => e.value > Duration.zero)
        .map((e) => ContributionEntry(e.key, e.value.inSeconds))
        .toList();

    // Day-keyed lookup used to resolve the contribution value of a hovered
    // cell. Mirrors how the heatmap indexes its own entries internally.
    final valueByDate = <DateTime, int>{
      for (final e in widget.activityData.entries)
        if (e.value > Duration.zero) _dayKey(e.key): e.value.inSeconds,
    };

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
          child: Listener(
            onPointerDown: (event) => _pointerKind = event.kind,
            child: MouseRegion(
              onHover: (event) => _handleHover(
                event,
                cellSize,
                firstDay,
                totalColumns,
                sequenceLength,
                valueByDate,
              ),
              onExit: (_) => _hideTooltip(),
              child: ContributionHeatmap(
                key: _heatmapKey,
                entries: entries,
                minDate: minDate,
                maxDate: maxDate,
                cellSize: cellSize,
                padding: const EdgeInsets.symmetric(
                  horizontal: padX,
                  vertical: 12,
                ),
                weekdayLabel: WeekdayLabel.githubLike,
                onCellTap: _showActivityInfo,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A small cursor-anchored tooltip that mirrors the snackbar's content.
class _ActivityTooltip extends StatelessWidget {
  final Offset globalPosition;
  final String message;

  const _ActivityTooltip({required this.globalPosition, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaSize = MediaQuery.sizeOf(context);

    const padH = 10.0;
    const padV = 6.0;

    // Self-contained style (inherit: false) so the tooltip never picks up the
    // framework's fallback text style (yellow, bold, underlined) when it is
    // rendered in the root Overlay. The font is taken from the theme to stay
    // consistent with the rest of the app.
    final base = theme.textTheme.bodySmall ?? const TextStyle();
    final style = TextStyle(
      inherit: false,
      color: theme.colorScheme.onInverseSurface,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      fontFamily: base.fontFamily,
      fontFamilyFallback: base.fontFamilyFallback,
      height: 1.25,
      decoration: TextDecoration.none,
    );

    // Measure the text so we can keep the tooltip on screen.
    final tp = TextPainter(
      text: TextSpan(text: message, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: 240);

    final tipWidth = tp.width + padH * 2;
    final tipHeight = tp.height + padV * 2;

    double left = globalPosition.dx + 12;
    if (left + tipWidth > mediaSize.width - 4) {
      left = mediaSize.width - 4 - tipWidth;
    }
    if (left < 4) left = 4;

    // Prefer above the cursor; fall back to below near the top edge.
    double top = globalPosition.dy - tipHeight - 10;
    if (top < 4) top = globalPosition.dy + 16;

    return Positioned(
      left: left,
      top: top,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          decoration: BoxDecoration(
            color: theme.colorScheme.inverseSurface,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(message, style: style),
        ),
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
