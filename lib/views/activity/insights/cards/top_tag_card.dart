import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
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

    String? topTag;
    var topTotal = Duration.zero;
    for (final MapEntry(key: tag, :value) in tagDuration.entries) {
      if (value > topTotal) {
        topTotal = value;
        topTag = tag;
      }
    }
    if (topTag == null) return null;
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '#${data.tag}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: context.theme.colorScheme.onSurface,
                ),
              ),
            ),
            for (final entry in data.topEntries)
              Transform.translate(
                offset: Offset(-4.0 * data.topEntries.indexOf(entry), 0),
                child: InsightCover(entry: entry, width: 26),
              ),
          ],
        ),
        const Spacer(),
        InsightHero(
          value: formatDurationCompact(data.duration),
          caption: 'across ${data.entryCount} tagged titles',
        ),
      ],
    );
  }
}
