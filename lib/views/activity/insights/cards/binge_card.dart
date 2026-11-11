import 'package:dionysos/data/activity/episode.dart';
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/utils/media_type.dart';
import 'package:dionysos/views/activity/insights/insight_card.dart';
import 'package:dionysos/views/activity/insights/insight_widgets.dart';
import 'package:flutter/material.dart';

class BingeData {
  final Entry entry;
  final Duration duration;
  final int episodes;
  final DateTime day;

  const BingeData({
    required this.entry,
    required this.duration,
    required this.episodes,
    required this.day,
  });
}

class BingeCard extends InsightCard<BingeData> {
  const BingeCard();

  @override
  String get id => 'binge';

  @override
  String get label => 'Binge';

  @override
  IconData get icon => Icons.bolt;

  @override
  Future<BingeData?> compute(InsightContext context) async {
    EpisodeActivity? longest;
    for (final activity in context.activities) {
      if (longest == null || activity.duration > longest.duration) {
        longest = activity;
      }
    }
    if (longest == null) return null;
    // Shorter than 45 minutes is a session, not a binge.
    if (longest.duration < const Duration(minutes: 45)) return null;
    return BingeData(
      entry: context.entryFor(longest),
      duration: longest.duration,
      // Ranges are sometimes recorded backwards.
      episodes: (longest.toepisode - longest.fromepisode).abs() + 1,
      day: InsightContext.dayKeyOf(longest.time),
    );
  }

  @override
  Widget build(BuildContext context, BingeData data) {
    final episodes = data.entry.mediaType
        .getEpisodeNames(data.episodes)
        .toLowerCase();
    return InsightCoverLayout(
      entry: data.entry,
      child: InsightBody(
        top: InsightHero(
          value: formatDurationCompact(data.duration),
          caption: 'in one sitting',
        ),
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.entry.title.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: InsightStyles.emphasis(context),
            ),
            Text(
              '${data.episodes} $episodes · ${formatDayLabel(data.day)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: InsightStyles.label(context),
            ),
          ],
        ),
      ),
    );
  }
}
