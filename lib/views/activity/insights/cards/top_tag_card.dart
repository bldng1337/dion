import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/views/activity/insights/insight_card.dart';
import 'package:dionysos/views/activity/insights/insight_widgets.dart';
import 'package:flutter/material.dart';

class TopTagData {
  final String tag;
  final Duration duration;
  final int entryCount;

  /// Up to three entries with this tag, longest-watched first.
  final List<Entry> topEntries;

  const TopTagData({
    required this.tag,
    required this.duration,
    required this.entryCount,
    required this.topEntries,
  });
}

class TopTagCard extends InsightCard<TopTagData> {
  const TopTagCard();

  @override
  String get id => 'topTag';

  @override
  String get label => 'Top Tag';

  @override
  IconData get icon => Icons.sell;

  @override
  Future<TopTagData?> compute(InsightContext context) async {
    final tagDuration = <String, Duration>{};
    final tagUids = <String, Set<String>>{};
    final uidDuration = <String, Duration>{};
    for (final activity in context.activities) {
      // Only saved rows carry genres; payload snapshots have none, which
      // keeps the tally exact-match only instead of guessing tags.
      final entry = context.entriesByUid[activity.entry.id.uid];
      final genres = entry is EntrySaved ? entry.genres : null;
      if (genres == null) continue;
      final uid = activity.entry.id.uid;
      uidDuration[uid] =
          (uidDuration[uid] ?? Duration.zero) + activity.duration;
      for (final genre in genres) {
        tagDuration[genre] =
            (tagDuration[genre] ?? Duration.zero) + activity.duration;
        tagUids.putIfAbsent(genre, () => {}).add(uid);
      }
    }
    if (tagDuration.isEmpty) return null;

    final MapEntry(key: topTag, value: topTotal) = tagDuration.entries.reduce(
      (a, b) => b.value > a.value ? b : a,
    );
    final uids = tagUids[topTag]!;
    // A tag needs two titles and an hour before it says anything.
    if (uids.length < 2 || topTotal < const Duration(hours: 1)) return null;

    final members = uids.toList()
      ..sort(
        (a, b) => (uidDuration[b] ?? Duration.zero).compareTo(
          uidDuration[a] ?? Duration.zero,
        ),
      );
    return TopTagData(
      tag: topTag,
      duration: topTotal,
      entryCount: uids.length,
      topEntries: [
        for (final uid in members.take(3))
          if (context.entriesByUid[uid] case final entry?) entry,
      ],
    );
  }

  @override
  Widget build(BuildContext context, TopTagData data) {
    return InsightAside(
      aside: InsightCoverFan(entries: data.topEntries),
      child: InsightBody(
        top: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '#${data.tag}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: InsightStyles.statement(context),
            ),
            const SizedBox(height: DionSpacing.xs),
            InsightHero(value: formatDurationCompact(data.duration)),
          ],
        ),
        bottom: Text(
          'across ${data.entryCount} tagged titles',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: InsightStyles.label(context),
        ),
      ),
    );
  }
}
