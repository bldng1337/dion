import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/views/activity/insights/insight_card.dart';
import 'package:dionysos/views/activity/insights/insight_widgets.dart';
import 'package:flutter/material.dart';

class TotalTimeData {
  /// Verb to measured time, largest first.
  final Map<String, Duration> current;
  final Duration currentTotal;
  final Duration previousTotal;

  const TotalTimeData({
    required this.current,
    required this.currentTotal,
    required this.previousTotal,
  });
}

class TotalTimeCard extends InsightCard<TotalTimeData> {
  const TotalTimeCard();

  @override
  String get id => 'totalTime';

  @override
  String get label => 'This Week';

  @override
  IconData get icon => Icons.timelapse;

  @override
  Future<TotalTimeData?> compute(InsightContext context) async {
    final weekStart = InsightContext.weekStartOf(context.now);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final currentTotal = context.totalIn(weekStart, weekEnd);
    if (currentTotal <= Duration.zero) return null;
    final byVerb = context.verbsIn(weekStart, weekEnd);
    final order = byVerb.keys.toList()
      ..sort((a, b) => byVerb[b]!.compareTo(byVerb[a]!));
    return TotalTimeData(
      current: {for (final verb in order) verb: byVerb[verb]!},
      currentTotal: currentTotal,
      previousTotal: context.totalIn(
        weekStart.subtract(const Duration(days: 7)),
        weekStart,
      ),
    );
  }

  @override
  Widget build(BuildContext context, TotalTimeData data) {
    final segments = [
      for (final MapEntry(key: verb, :value) in data.current.entries)
        Segment(label: verb, duration: value, color: verbColor(context, verb)),
    ];
    final caption = data.previousTotal <= Duration.zero
        ? 'tracked this week'
        : '${_delta(data.currentTotal, data.previousTotal)} vs last week '
              '(${formatDurationCompact(data.previousTotal)})';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InsightHero(
          value: formatDurationCompact(data.currentTotal),
          caption: caption,
        ),
        const Spacer(),
        SegmentBar(segments: segments),
        const SizedBox(height: DionSpacing.sm),
        SegmentLegend(segments: segments),
      ],
    );
  }

  String _delta(Duration current, Duration previous) {
    final percent =
        ((current.inMilliseconds - previous.inMilliseconds) /
                previous.inMilliseconds *
                100)
            .round();
    return percent >= 0 ? '+$percent%' : '$percent%';
  }
}
