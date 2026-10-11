import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/activity/activity.dart';
import 'package:dionysos/data/activity/episode.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/utils/async.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/media_type.dart';
import 'package:dionysos/utils/time.dart';
import 'package:dionysos/views/activity.dart';
import 'package:dionysos/views/dialog/next_release.dart';
import 'package:dionysos/widgets/buttons/clickable.dart';
import 'package:dionysos/widgets/drawer.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:flutter/material.dart'
    show IconButton, Icons, VisualDensity;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// A scheduled release shown on the calendar: the saved entry the date
/// belongs to and the concrete release time.
class DayRelease {
  final EntrySaved entry;
  final DateTime release;

  const DayRelease(this.entry, this.release);
}

/// Day popup for the calendar: the day's releases, its listening / reading
/// sessions and the time spent per media type.
Future<void> showDayDetails(
  BuildContext context, {
  required DateTime day,
  required List<DayRelease> releases,
  required List<Activity> activities,
}) {
  return showDionPanel(
    context: context,
    builder: (dialogContext) => _DayDetailsPanel(
      day: day,
      releases: releases,
      activities: activities,
    ),
  );
}

class _DayDetailsPanel extends StatelessWidget {
  final DateTime day;
  final List<DayRelease> releases;
  final List<Activity> activities;

  const _DayDetailsPanel({
    required this.day,
    required this.releases,
    required this.activities,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DionSpacing.lg,
              DionSpacing.lg,
              DionSpacing.sm,
              DionSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    day.toDateString(),
                    style: context.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Close',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                DionSpacing.lg,
                0,
                DionSpacing.lg,
                DionSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DayStats(activities: activities),
                  const _SectionHeader('Releases'),
                  if (releases.isEmpty)
                    const _MutedText('No releases scheduled for this day.')
                  else
                    for (final release in releases) _ReleaseRow(release),
                  const _SectionHeader('Activity'),
                  if (activities.whereType<EpisodeActivity>().isEmpty)
                    const _MutedText('No activity recorded for this day.')
                  else
                    _ActivityList(
                      activities: activities.whereType<EpisodeActivity>().toList(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayStats extends StatelessWidget {
  final List<Activity> activities;

  const _DayStats({required this.activities});

  @override
  Widget build(BuildContext context) {
    final chips = mediaStatChips(activities.whereType<EpisodeActivity>());
    if (chips.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: DionSpacing.xs),
        child: _MutedText('No time spent on this day yet.'),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: DionSpacing.xs),
      child: Wrap(
        spacing: DionSpacing.sm,
        runSpacing: DionSpacing.sm,
        children: chips,
      ),
    );
  }
}

/// Time totals per action verb ("Listened for 3 hours", ...), merging media
/// types that share a verb (comic and book are both "Read").
List<MediaStatChip> mediaStatChips(Iterable<EpisodeActivity> activities) {
  final durations = <String, Duration>{};
  final icons = <String, IconData>{};
  for (final activity in activities) {
    if (activity.duration <= Duration.zero) continue;
    final media = activity.entry.mediaType;
    final verb = media.activityVerb;
    durations[verb] = (durations[verb] ?? Duration.zero) + activity.duration;
    icons.putIfAbsent(verb, () => media.icon);
  }
  return [
    for (final MapEntry(key: verb, :value) in durations.entries)
      MediaStatChip(
        label: verb,
        icon: icons[verb]!,
        duration: value,
      ),
  ];
}

/// A "Listened for 3 hours" style stat chip, shared with the month summary.
///
/// A plain Container rather than DionContainer: the container's alignment
/// makes it expand to the full Wrap width instead of hugging its content.
class MediaStatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Duration duration;

  const MediaStatChip({
    super.key,
    required this.label,
    required this.icon,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: context.theme.colorScheme.onSurfaceVariant,
          ).paddingOnly(right: 5),
          Text(
            '$label for ${duration.formatrelative()}',
            style: context.labelSmall?.copyWith(
              color: context.theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, DionSpacing.lg, 2, DionSpacing.sm),
      child: Text(
        title.toUpperCase(),
        style: DionTypography.sectionHeader(context.textTertiary),
      ),
    );
  }
}

class _MutedText extends StatelessWidget {
  final String text;

  const _MutedText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.bodySmall?.copyWith(
        color: context.theme.colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }
}

class _ReleaseRow extends StatelessWidget {
  final DayRelease release;

  const _ReleaseRow(this.release);

  @override
  Widget build(BuildContext context) {
    final entry = release.entry;
    final manual = entry.nextReleaseOverride != null;
    return Clickable(
      onTap: () {
        // Push first, then close the popup on top of the detail page.
        context.push('/detail', extra: [entry]);
        Navigator.of(context).pop();
      },
      onLongTap: () => showNextReleaseEditor(context, entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 56,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DionRadius.sm),
                child: DionImage.fromLink(
                  link: entry.cover,
                  boxFit: BoxFit.cover,
                  errorWidget: _CoverFallback(entry: entry),
                  loadingBuilder: (context) => ColoredBox(
                    color: context.theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        manual ? Icons.event : Icons.auto_awesome,
                        size: 12,
                        color: context.theme.colorScheme.onSurface
                            .withValues(alpha: 0.45),
                      ).paddingOnly(right: 4),
                      Text(
                        manual ? 'Set manually' : 'Predicted',
                        style: context.labelSmall?.copyWith(
                          color: context.theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        release.release.formatrelative(allowFromNow: true),
                        style: context.labelSmall?.copyWith(
                          color: context.theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  final EntrySaved entry;

  const _CoverFallback({required this.entry});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        entry.mediaType.icon,
        size: 14,
        color: context.theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _ActivityList extends StatefulWidget {
  final List<EpisodeActivity> activities;

  const _ActivityList({required this.activities});

  @override
  State<_ActivityList> createState() => _ActivityListState();
}

class _ActivityListState extends State<_ActivityList> {
  late final Future<List<ActivityItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ActivityItem>> _load() async {
    final items = <ActivityItem>[];
    for (final activity in widget.activities) {
      final item = await ActivityItem.getActionItem(activity);
      if (!mounted) return items;
      items.add(item);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return LoadingBuilder<List<ActivityItem>>(
      future: _future,
      loading: (context) =>
          const DionProgressBar().paddingSymmetric(vertical: DionSpacing.lg),
      builder: (context, items) => Column(
        children: [for (final item in items) item.render(context)],
      ),
    );
  }
}
