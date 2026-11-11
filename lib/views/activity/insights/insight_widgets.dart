import 'dart:math' as math;

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moment_dart/moment_dart.dart';

/// Width over height of a typical cover.
const coverAspectRatio = 2 / 3;

/// "6h 12m", "45m", "3d 2h" — hero-number style durations, unlike the fuzzy
/// `formatrelative` used in the feed.
String formatDurationCompact(Duration duration) {
  if (duration.inSeconds < 60) return '${duration.inSeconds}s';
  if (duration.inMinutes < 60) return '${duration.inMinutes}m';
  if (duration.inHours < 24) {
    final minutes = duration.inMinutes % 60;
    return minutes > 0
        ? '${duration.inHours}h ${minutes}m'
        : '${duration.inHours}h';
  }
  final hours = duration.inHours % 24;
  return hours > 0 ? '${duration.inDays}d ${hours}h' : '${duration.inDays}d';
}

/// Human label for a UTC day key: Today / Yesterday, otherwise "Sun, Mar 3".
String formatDayLabel(DateTime utcDay) {
  final today = DateTime.now().toUtc();
  final day = DateTime.utc(today.year, today.month, today.day);
  if (utcDay == day) return 'Today';
  if (utcDay == day.subtract(const Duration(days: 1))) return 'Yesterday';
  return Moment(utcDay.toLocal()).format('ddd, MMM d');
}

String pluralize(int count, String singular, [String? plural]) =>
    count == 1 ? singular : (plural ?? '${singular}s');

/// Segment colors of the listened/read/... bar. Two media verbs are usually
/// enough in practice (comics and books both count as "Read").
Color verbColor(BuildContext context, String verb) {
  final scheme = context.theme.colorScheme;
  return switch (verb) {
    'Listened' => scheme.tertiary,
    'Read' => scheme.primary,
    'Watched' => scheme.secondary,
    _ => scheme.onSurfaceVariant,
  };
}

/// Text styles shared by every card so they read as one family.
abstract final class InsightStyles {
  static TextStyle hero(BuildContext context) =>
      DionTypography.displayLarge(context.theme.colorScheme.onSurface)
          .copyWith(fontSize: 26, height: 1.15);

  static TextStyle unit(BuildContext context) =>
      DionTypography.titleSmall(context.theme.colorScheme.onSurfaceVariant);

  /// A one-sentence insight used in place of a hero number.
  static TextStyle statement(BuildContext context) =>
      DionTypography.titleSmall(context.theme.colorScheme.onSurface)
          .copyWith(fontWeight: FontWeight.w600, height: 1.3);

  static TextStyle body(BuildContext context) =>
      DionTypography.bodySmall(context.theme.colorScheme.onSurfaceVariant);

  static TextStyle emphasis(BuildContext context) =>
      DionTypography.bodySmall(context.theme.colorScheme.onSurface)
          .copyWith(fontWeight: FontWeight.w500);

  static TextStyle label(BuildContext context) =>
      DionTypography.labelSmall(context.theme.colorScheme.onSurfaceVariant);

  static TextStyle axis(BuildContext context) =>
      DionTypography.labelSmall(context.theme.colorScheme.onSurfaceVariant)
          .copyWith(fontSize: 9.5, letterSpacing: 0);
}

/// A cover that fills its parent and degrades to the entry's initial.
/// Tapping opens the entry's detail page. Size it from outside
/// ([InsightAspectBox], [InsightCoverLayout], a fixed [SizedBox], ...).
class InsightCover extends StatelessWidget {
  final Entry? entry;

  const InsightCover({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final entry = this.entry;
    final placeholder = ColoredBox(
      color: context.theme.colorScheme.surfaceContainerHighest,
    );
    return GestureDetector(
      onTap: entry == null
          ? null
          : () => context.push('/detail', extra: [entry]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DionRadius.sm),
        child: SizedBox.expand(
          child: entry == null
              ? placeholder
              : LayoutBuilder(
                  builder: (context, constraints) => DionImage.fromLink(
                    link: entry.cover,
                    boxFit: BoxFit.cover,
                    // Bucketed so small layout changes keep the decoded
                    // image instead of re-decoding at every new width.
                    cacheWidth: constraints.hasBoundedWidth
                        ? math.max(32, (constraints.maxWidth / 32).ceil() * 32)
                        : 96,
                    errorWidget: _CoverFallback(entry: entry),
                    loadingBuilder: (context) => placeholder,
                  ),
                ),
        ),
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  final Entry entry;

  const _CoverFallback({required this.entry});

  @override
  Widget build(BuildContext context) {
    final title = entry.title.trim();
    final initial = title.isNotEmpty
        ? title.substring(0, 1).toUpperCase()
        : '?';
    final scheme = context.theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        // DionImage wraps missing covers in a FittedBox, which lays this out
        // unbounded; a nominal cover size lets the FittedBox scale it.
        final bounded =
            constraints.hasBoundedWidth && constraints.hasBoundedHeight;
        final width = bounded ? constraints.maxWidth : 48.0;
        final height = bounded ? constraints.maxHeight : 72.0;
        final side = math.min(width, height);
        return SizedBox(
          width: width,
          height: height,
          child: ColoredBox(
            color: scheme.surfaceContainerHighest,
            // A glyph below this size is noise, and a zero font size is
            // not safe to hand to every renderer.
            child: side < 12
                ? null
                : Center(
                    child: Text(
                      initial,
                      maxLines: 1,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontSize: side * 0.45,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

/// The largest box of [aspectRatio] that fits the incoming constraints.
class InsightAspectBox extends StatelessWidget {
  final double aspectRatio;
  final Widget child;

  const InsightAspectBox({
    super.key,
    this.aspectRatio = coverAspectRatio,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(
          constraints.maxWidth,
          constraints.maxHeight * aspectRatio,
        );
        if (!width.isFinite) return child;
        return SizedBox(
          width: width,
          height: width / aspectRatio,
          child: child,
        );
      },
    );
  }
}

/// Scales [child] down uniformly when it is taller than the available
/// height, instead of overflowing. The child is laid out at the full
/// available width, so text still wraps and ellipsizes normally first.
class InsightScaleDown extends StatelessWidget {
  final Widget child;
  final AlignmentGeometry alignment;

  const InsightScaleDown({
    super.key,
    required this.child,
    this.alignment = AlignmentDirectional.topStart,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth) return child;
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: SizedBox(width: constraints.maxWidth, child: child),
        );
      },
    );
  }
}

/// Body layout of a card: [top] pinned to the top edge, [bottom] to the
/// bottom edge, and neither can overflow. Both are scaled down when the card
/// is too short for them (large text scale, small windows).
///
/// With [fillBottom] the bottom (usually a chart) gets all height the top
/// leaves over, but never less than [minBottomHeight]; otherwise it is sized
/// to its content, up to half the card.
class InsightBody extends StatelessWidget {
  final Widget top;
  final Widget? bottom;
  final bool fillBottom;
  final double minBottomHeight;

  const InsightBody({
    super.key,
    required this.top,
    this.bottom,
    this.fillBottom = false,
    this.minBottomHeight = 24,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = this.bottom;
    return CustomMultiChildLayout(
      delegate: _InsightBodyDelegate(
        fillBottom: fillBottom,
        minBottomHeight: minBottomHeight,
      ),
      children: [
        LayoutId(
          id: _InsightBodySlot.top,
          child: InsightScaleDown(child: top),
        ),
        if (bottom != null)
          LayoutId(
            id: _InsightBodySlot.bottom,
            child: fillBottom
                ? bottom
                : InsightScaleDown(
                    alignment: AlignmentDirectional.bottomStart,
                    child: bottom,
                  ),
          ),
      ],
    );
  }
}

enum _InsightBodySlot { top, bottom }

class _InsightBodyDelegate extends MultiChildLayoutDelegate {
  final bool fillBottom;
  final double minBottomHeight;

  _InsightBodyDelegate({
    required this.fillBottom,
    required this.minBottomHeight,
  });

  static const _gap = DionSpacing.sm;

  @override
  void performLayout(Size size) {
    final hasBottom = hasChild(_InsightBodySlot.bottom);
    if (!hasBottom) {
      layoutChild(_InsightBodySlot.top, BoxConstraints.loose(size));
      positionChild(_InsightBodySlot.top, Offset.zero);
      return;
    }
    if (fillBottom) {
      final topSize = layoutChild(
        _InsightBodySlot.top,
        BoxConstraints(
          maxWidth: size.width,
          maxHeight: math.max(0, size.height - minBottomHeight - _gap),
        ),
      );
      positionChild(_InsightBodySlot.top, Offset.zero);
      final available = math.max(0.0, size.height - topSize.height - _gap);
      layoutChild(
        _InsightBodySlot.bottom,
        BoxConstraints.tightFor(width: size.width, height: available),
      );
      positionChild(
        _InsightBodySlot.bottom,
        Offset(0, size.height - available),
      );
      return;
    }
    final bottomSize = layoutChild(
      _InsightBodySlot.bottom,
      BoxConstraints(maxWidth: size.width, maxHeight: size.height / 2),
    );
    positionChild(
      _InsightBodySlot.bottom,
      Offset(0, size.height - bottomSize.height),
    );
    layoutChild(
      _InsightBodySlot.top,
      BoxConstraints(
        maxWidth: size.width,
        maxHeight: math.max(0, size.height - bottomSize.height - _gap),
      ),
    );
    positionChild(_InsightBodySlot.top, Offset.zero);
  }

  @override
  bool shouldRelayout(_InsightBodyDelegate oldDelegate) =>
      oldDelegate.fillBottom != fillBottom ||
      oldDelegate.minBottomHeight != minBottomHeight;
}

/// Leading cover at full card height next to [child]. The cover is dropped
/// when the card is too narrow for it to be recognizable.
class InsightCoverLayout extends StatelessWidget {
  final Entry? entry;
  final Widget child;

  const InsightCoverLayout({
    super.key,
    required this.entry,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final coverWidth = math.min(
          constraints.maxHeight * coverAspectRatio,
          constraints.maxWidth * 0.3,
        );
        if (coverWidth < 40) return child;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: coverWidth,
              child: InsightCover(entry: entry),
            ),
            const SizedBox(width: DionSpacing.md),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

/// [child] with a trailing graphic at full card height, capped to
/// [maxAsideFraction] of the width. The graphic is dropped below
/// [minWidth] so the text keeps enough room.
class InsightAside extends StatelessWidget {
  final Widget child;
  final Widget aside;
  final double maxAsideFraction;
  final double minWidth;

  const InsightAside({
    super.key,
    required this.child,
    required this.aside,
    this.maxAsideFraction = 0.45,
    this.minWidth = 230,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < minWidth) return child;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: child),
            const SizedBox(width: DionSpacing.md),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * maxAsideFraction,
              ),
              child: aside,
            ),
          ],
        );
      },
    );
  }
}

/// Up to a handful of covers fanned out, first entry in front. Sized from
/// the available height and shrunk to the available width.
class InsightCoverFan extends StatelessWidget {
  final List<Entry> entries;

  const InsightCoverFan({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final ring = context.theme.colorScheme.surfaceContainer;
    return LayoutBuilder(
      builder: (context, constraints) {
        var coverHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 96.0;
        var coverWidth = coverHeight * coverAspectRatio;
        final steps = entries.length - 1;
        const overlap = 0.45;
        final total = coverWidth * (1 + steps * overlap);
        if (constraints.maxWidth.isFinite && total > constraints.maxWidth) {
          final scale = constraints.maxWidth / total;
          coverWidth *= scale;
          coverHeight *= scale;
        }
        final step = coverWidth * overlap;
        return SizedBox(
          width: coverWidth + steps * step,
          height: constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : coverHeight,
          child: Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [
              for (var i = entries.length - 1; i >= 0; i--)
                PositionedDirectional(
                  start: i * step,
                  width: coverWidth,
                  height: coverHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: ring,
                      borderRadius: BorderRadius.circular(DionRadius.sm + 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(1.5),
                      child: InsightCover(entry: entries[i]),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Big number + unit, with an optional caption below. The number scales
/// down instead of overflowing on narrow cards.
class InsightHero extends StatelessWidget {
  final String value;
  final String? unit;
  final String? caption;
  final int captionLines;

  const InsightHero({
    super.key,
    required this.value,
    this.unit,
    this.caption,
    this.captionLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: value, style: InsightStyles.hero(context)),
                if (unit != null)
                  TextSpan(text: ' $unit', style: InsightStyles.unit(context)),
              ],
            ),
            maxLines: 1,
            softWrap: false,
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(
            caption!,
            maxLines: captionLines,
            overflow: TextOverflow.ellipsis,
            style: InsightStyles.body(context),
          ),
        ],
      ],
    );
  }
}

/// One proportional segment of [SegmentBar].
class Segment {
  final String label;
  final Duration duration;
  final Color color;

  const Segment({
    required this.label,
    required this.duration,
    required this.color,
  });
}

/// Horizontal stacked bar showing per-segment shares of a total.
class SegmentBar extends StatelessWidget {
  final List<Segment> segments;
  final double height;

  const SegmentBar({super.key, required this.segments, this.height = 10});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(DionRadius.xs),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            for (final segment in segments)
              if (segment.duration > Duration.zero)
                Expanded(
                  flex: segment.duration.inSeconds.clamp(1, 1 << 30),
                  child: ColoredBox(color: segment.color),
                ),
          ],
        ),
      ),
    );
  }
}

/// Legend row for a [SegmentBar]: colored dot + "Read · 4h 32m".
class SegmentLegend extends StatelessWidget {
  final List<Segment> segments;

  const SegmentLegend({super.key, required this.segments});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DionSpacing.md,
      runSpacing: 2,
      children: [
        for (final segment in segments)
          if (segment.duration > Duration.zero)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: segment.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: DionSpacing.xs),
                Flexible(
                  child: Text(
                    '${segment.label} · '
                    '${formatDurationCompact(segment.duration)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: InsightStyles.label(context),
                  ),
                ),
              ],
            ),
      ],
    );
  }
}

/// Vertical bar chart filling its parent (which must bound the height).
/// Bars are scaled to the largest value; the index range
/// [highlightFrom]..[highlightTo] (inclusive, may wrap around the end) is
/// tinted with [accent] and the rest stay muted. Without a range every bar
/// uses [accent]. [labels] maps bar indices to axis labels, shown when there
/// is room for them.
class BarStrip extends StatelessWidget {
  final List<double> values;
  final Color accent;
  final int? highlightFrom;
  final int? highlightTo;
  final Map<int, String> labels;

  const BarStrip({
    super.key,
    required this.values,
    required this.accent,
    this.highlightFrom,
    this.highlightTo,
    this.labels = const {},
  });

  BarStrip.durations({
    super.key,
    required List<Duration> values,
    required this.accent,
    this.highlightFrom,
    this.highlightTo,
    this.labels = const {},
  }) : values = [for (final value in values) value.inSeconds.toDouble()];

  static const _maxBarWidth = 28.0;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final maxValue = values.fold<double>(0, math.max);
    final muted = context.theme.colorScheme.onSurfaceVariant;
    final axisStyle = InsightStyles.axis(context);
    final labelHeight =
        MediaQuery.textScalerOf(context).scale(axisStyle.fontSize!) *
        axisStyle.height!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final showLabels =
            labels.isNotEmpty && constraints.maxHeight >= labelHeight * 3;
        final cellWidth = constraints.maxWidth / values.length;
        final barFactor = cellWidth <= 0
            ? 1.0
            : math.min(0.8, _maxBarWidth / cellWidth);
        final bars = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < values.length; i++)
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    widthFactor: barFactor,
                    heightFactor: values[i] <= 0 || maxValue <= 0
                        ? 0.04
                        : (values[i] / maxValue).clamp(0.08, 1.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: values[i] <= 0
                            ? muted.withValues(alpha: 0.18)
                            : _inHighlight(i)
                            ? accent
                            : muted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(DionRadius.xs),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
        if (!showLabels) return bars;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: bars),
            const SizedBox(height: 2),
            SizedBox(
              height: labelHeight,
              child: Row(
                children: [
                  for (var i = 0; i < values.length; i++)
                    Expanded(
                      child: labels[i] == null
                          ? const SizedBox.shrink()
                          : Text(
                              labels[i]!,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.visible,
                              textAlign: TextAlign.center,
                              style: axisStyle,
                            ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  bool _inHighlight(int index) {
    if (highlightFrom == null || highlightTo == null) return true;
    if (highlightFrom! <= highlightTo!) {
      return index >= highlightFrom! && index <= highlightTo!;
    }
    // Wrap-around range (e.g. 22-02 across midnight).
    return index >= highlightFrom! || index <= highlightTo!;
  }
}

/// One row of square day cells, most recent on the right. Shows as many of
/// the trailing [days] as fit the width; the last cell is today.
class DayDots extends StatelessWidget {
  final List<bool> days;
  final Color accent;

  const DayDots({super.key, required this.days, required this.accent});

  static const _gap = 3.0;
  static const _minCell = 8.0;
  static const _maxCell = 13.0;

  @override
  Widget build(BuildContext context) {
    final muted = context.theme.colorScheme.onSurfaceVariant;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : days.length * (_maxCell + _gap);
        final count = math.min(
          days.length,
          math.max(1, ((width + _gap) / (_minCell + _gap)).floor()),
        );
        final cell = math.min(
          _maxCell,
          ((width - _gap * (count - 1)) / count).floorToDouble(),
        );
        if (cell <= 0) return const SizedBox.shrink();
        final shown = days.sublist(days.length - count);
        return SizedBox(
          height: cell,
          child: Row(
            children: [
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                Container(
                  width: cell,
                  height: cell,
                  decoration: BoxDecoration(
                    color: shown[i] ? accent : muted.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(DionRadius.xs),
                    border: i == shown.length - 1
                        ? Border.all(color: accent, width: 1.2)
                        : null,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
