import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/views/activity/insights/insight_card.dart';
import 'package:dionysos/views/activity/insights/insight_widgets.dart';
import 'package:flutter/material.dart';

/// Upper bounds of the session-length buckets; the last bucket is open.
const _bucketLimits = [
  Duration(minutes: 10),
  Duration(minutes: 30),
  Duration(hours: 1),
  Duration(hours: 2),
];
const _bucketLabels = ['<10m', '<30m', '<1h', '<2h', '2h+'];

class SessionLengthData {
  final Duration median;
  final int sessions;

  /// Session count per bucket of [_bucketLimits].
  final List<int> buckets;

  const SessionLengthData({
    required this.median,
    required this.sessions,
    required this.buckets,
  });

  int get topBucket {
    var top = 0;
    for (var i = 1; i < buckets.length; i++) {
      if (buckets[i] > buckets[top]) top = i;
    }
    return top;
  }
}

/// How long a typical session lasts.
class SessionLengthCard extends InsightCard<SessionLengthData> {
  const SessionLengthCard();

  @override
  String get id => 'sessionLength';

  @override
  String get label => 'Sessions';

  @override
  IconData get icon => Icons.av_timer;

  @override
  double get weight => 0.75;

  @override
  Future<SessionLengthData?> compute(InsightContext context) async {
    if (context.activities.length < 8) return null;
    final durations = [for (final a in context.activities) a.duration]..sort();
    final buckets = List.filled(_bucketLimits.length + 1, 0);
    for (final duration in durations) {
      var bucket = _bucketLimits.indexWhere((limit) => duration < limit);
      if (bucket < 0) bucket = _bucketLimits.length;
      buckets[bucket]++;
    }
    return SessionLengthData(
      median: durations[durations.length ~/ 2],
      sessions: durations.length,
      buckets: buckets,
    );
  }

  @override
  Widget build(BuildContext context, SessionLengthData data) {
    final top = data.topBucket;
    return InsightBody(
      fillBottom: true,
      minBottomHeight: 28,
      top: InsightHero(
        value: formatDurationCompact(data.median),
        caption: 'typical session · ${data.sessions} in 6 months',
        captionLines: 1,
      ),
      bottom: BarStrip(
        values: [for (final count in data.buckets) count.toDouble()],
        accent: context.theme.colorScheme.primary,
        highlightFrom: top,
        highlightTo: top,
        labels: {
          for (var i = 0; i < _bucketLabels.length; i++) i: _bucketLabels[i],
        },
      ),
    );
  }
}
