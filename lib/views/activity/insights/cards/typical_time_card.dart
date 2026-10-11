import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/utils/media_type.dart';
import 'package:dionysos/views/activity/insights/insight_card.dart';
import 'package:dionysos/views/activity/insights/insight_widgets.dart';
import 'package:flutter/material.dart';

class TypicalTimeData {
  /// Inclusive first hour of the peak window, in local wall time.
  final int fromHour;

  /// Exclusive end hour; may be smaller than [fromHour] when the window
  /// wraps around midnight.
  final int toHour;

  /// Noun form of the dominant media verb, e.g. "listening".
  final String verbNoun;

  final List<Duration> histogram;
  final double share;

  const TypicalTimeData({
    required this.fromHour,
    required this.toHour,
    required this.verbNoun,
    required this.histogram,
    required this.share,
  });
}

const _verbNouns = {
  'Listened': 'listening',
  'Read': 'reading',
  'Watched': 'watching',
  'Consumed': 'activity',
};

class TypicalTimeCard extends InsightCard<TypicalTimeData> {
  const TypicalTimeCard();

  @override
  String get id => 'typicalTime';

  @override
  String get label => 'Daily Rhythm';

  @override
  IconData get icon => Icons.schedule;

  @override
  Future<TypicalTimeData?> compute(InsightContext context) async {
    if (context.activities.length < 5) return null;

    final histogram = List<Duration>.filled(24, Duration.zero);
    final verbTotals = <String, Duration>{};
    var total = Duration.zero;
    for (final activity in context.activities) {
      histogram[activity.time.toLocal().hour] += activity.duration;
      final verb = activity.entry.mediaType.activityVerb;
      verbTotals[verb] =
          (verbTotals[verb] ?? Duration.zero) + activity.duration;
      total += activity.duration;
    }
    if (total < const Duration(minutes: 30)) return null;

    var bestStart = 0;
    var bestTotal = Duration.zero;
    for (var start = 0; start < 24; start++) {
      final window = histogram[start] + histogram[(start + 1) % 24];
      if (window > bestTotal) {
        bestTotal = window;
        bestStart = start;
      }
    }
    final share = bestTotal.inMicroseconds / total.inMicroseconds;
    // A peak holding under a third of the time is not a "typical" time.
    if (share < 0.3) return null;

    final topVerb = verbTotals.entries
        .reduce((a, b) => b.value > a.value ? b : a)
        .key;
    return TypicalTimeData(
      fromHour: bestStart,
      toHour: (bestStart + 2) % 24,
      verbNoun: _verbNouns[topVerb] ?? 'activity',
      histogram: histogram,
      share: share,
    );
  }

  @override
  Widget build(BuildContext context, TypicalTimeData data) {
    final scheme = context.theme.colorScheme;
    String hourLabel(int hour) => '${hour.toString().padLeft(2, '0')}:00';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Most ${data.verbNoun} happens between '
          '${hourLabel(data.fromHour)} and ${hourLabel(data.toHour)}.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${(data.share * 100).round()}% of your time in these hours',
          style: context.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const Spacer(),
        BarStrip(
          values: data.histogram,
          accent: scheme.primary,
          highlightFrom: data.fromHour,
          highlightTo: (data.toHour + 23) % 24,
        ),
      ],
    );
  }
}
