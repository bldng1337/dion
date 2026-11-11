import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/views/activity/insights/insight_card.dart';
import 'package:dionysos/views/activity/insights/insight_widgets.dart';
import 'package:flutter/material.dart';

class TotalTrackedData {
  final Duration total;

  /// Distinct titles with measured time in the window.
  final int titles;

  final int episodes;
  final List<Duration> last30Days;

  const TotalTrackedData({
    required this.total,
    required this.titles,
    required this.episodes,
    required this.last30Days,
  });
}

class TotalTrackedCard extends InsightCard<TotalTrackedData> {
  const TotalTrackedCard();

  @override
  String get id => 'totalTracked';

  @override
  String get label => 'Time Tracked';

  @override
  IconData get icon => Icons.hourglass_bottom;

  @override
  double get weight => 0.75;

  @override
  Future<TotalTrackedData?> compute(InsightContext context) async {
    var total = Duration.zero;
    for (final duration in context.dailyTotals.values) {
      total += duration;
    }
    if (total < const Duration(hours: 1)) return null;

    final titles = <String>{};
    var episodes = 0;
    for (final activity in context.activities) {
      titles.add(activity.entry.id.uid);
      // Ranges are sometimes recorded backwards.
      episodes += (activity.toepisode - activity.fromepisode).abs() + 1;
    }

    final today = context.today;
    final last30 = List.generate(
      30,
      (i) =>
          context.dailyTotals[today.subtract(Duration(days: 29 - i))] ??
          Duration.zero,
    );
    return TotalTrackedData(
      total: total,
      titles: titles.length,
      episodes: episodes,
      last30Days: last30,
    );
  }

  @override
  Widget build(BuildContext context, TotalTrackedData data) {
    return InsightBody(
      fillBottom: true,
      top: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InsightHero(
            value: formatDurationCompact(data.total),
            caption: 'tracked in the last year',
            captionLines: 1,
          ),
          Text(
            '${data.titles} ${pluralize(data.titles, 'title')} · '
            '${data.episodes} ${pluralize(data.episodes, 'episode')} '
            'in 6 months',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: InsightStyles.label(context),
          ),
        ],
      ),
      bottom: BarStrip.durations(
        values: data.last30Days,
        accent: context.theme.colorScheme.primary,
      ),
    );
  }
}
