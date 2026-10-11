import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moment_dart/moment_dart.dart';

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

/// A cover image that degrades to the entry's initial. Tapping opens the
/// entry's detail page. Either sized via [width]/[height] or filling the
/// parent with [expand].
class InsightCover extends StatelessWidget {
  final Entry? entry;
  final double width;
  final double? height;
  final bool expand;

  const InsightCover({
    super.key,
    required this.entry,
    this.width = 64,
    this.height,
  }) : expand = false;

  const InsightCover.expand({super.key, required this.entry})
    : width = 0,
      height = null,
      expand = true;

  @override
  Widget build(BuildContext context) {
    final size = height ?? width;
    return GestureDetector(
      onTap: entry == null
          ? null
          : () => context.push('/detail', extra: [entry!]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DionRadius.sm),
        child: SizedBox(
          width: expand ? double.infinity : width,
          height: expand ? double.infinity : size,
          child: entry == null
              ? ColoredBox(
                  color: context.theme.colorScheme.surfaceContainerHighest,
                )
              : DionImage.fromLink(
                  link: entry!.cover,
                  boxFit: BoxFit.cover,
                  errorWidget: _CoverFallback(entry: entry!, size: size),
                  loadingBuilder: (context) => ColoredBox(
                    color: context.theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
        ),
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  final Entry entry;
  final double size;

  const _CoverFallback({required this.entry, required this.size});

  @override
  Widget build(BuildContext context) {
    final title = entry.title.trim();
    final initial = title.isNotEmpty
        ? title.substring(0, 1).toUpperCase()
        : '?';
    return ColoredBox(
      color: context.theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            color: context.theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Big number + unit line, the hero of a card.
class InsightHero extends StatelessWidget {
  final String value;
  final String? unit;
  final String? caption;

  const InsightHero({super.key, required this.value, this.unit, this.caption});

  @override
  Widget build(BuildContext context) {
    final color = context.theme.colorScheme.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: DionTypography.displayLarge(color).copyWith(fontSize: 26),
            ),
            if (unit != null) ...[
              const SizedBox(width: 4),
              Text(
                unit!,
                style: DionTypography.titleMedium(
                  context.theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(
            caption!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.bodySmall?.copyWith(
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
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
                  flex: segment.duration.inMilliseconds.clamp(1, 1 << 30),
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
      runSpacing: DionSpacing.xs,
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
                const SizedBox(width: 5),
                Text(
                  '${segment.label} · ${formatDurationCompact(segment.duration)}',
                  style: context.labelSmall?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
      ],
    );
  }
}

/// Vertical micro-bar strip (hour histogram, weekday bars, ...). Bars are
/// laid out evenly and scaled to the largest value; the index range
/// [highlightFrom]..[highlightTo] (inclusive, may wrap around the end) is
/// tinted with [accent], the rest stay muted.
class BarStrip extends StatelessWidget {
  final List<Duration> values;
  final Color accent;
  final int? highlightFrom;
  final int? highlightTo;
  final double? height;

  const BarStrip({
    super.key,
    required this.values,
    required this.accent,
    this.highlightFrom,
    this.highlightTo,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    var maxMicros = 0;
    for (final value in values) {
      if (value.inMicroseconds > maxMicros) maxMicros = value.inMicroseconds;
    }
    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    widthFactor: 1,
                    heightFactor: maxMicros == 0
                        ? 0
                        : (values[i].inMicroseconds / maxMicros).clamp(
                            0.06,
                            1.0,
                          ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _inHighlight(i)
                            ? accent
                            : context.theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(DionRadius.xs),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _inHighlight(int index) {
    if (highlightFrom == null || highlightTo == null) return false;
    if (highlightFrom! <= highlightTo!) {
      return index >= highlightFrom! && index <= highlightTo!;
    }
    // Wrap-around range (e.g. 22-02 across midnight).
    return index >= highlightFrom! || index <= highlightTo!;
  }
}
