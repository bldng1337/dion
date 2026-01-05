import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/activity/activity.dart';
import 'package:dionysos/data/activity/episode.dart';
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/routes.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/media_type.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/time.dart';
import 'package:dionysos/widgets/activity_chart.dart';

import 'package:dionysos/widgets/container/container.dart';
import 'package:dionysos/widgets/buttons/clickable.dart';
import 'package:dionysos/widgets/dynamic_grid.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:moment_dart/moment_dart.dart';

abstract class IRenderable {
  Widget render(BuildContext context);
}

/// A header to separate activities by day. Replaces the previous `Divider` name.
class DateHeader implements IRenderable {
  final DateTime date;
  final Duration duration;
  const DateHeader(this.date, this.duration);

  @override
  Widget render(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
      child: Row(
        children: [
          Text(
            date.toDateString(),
            style: context.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: context.theme.colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          if (duration > Duration.zero)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: DionContainer(
                color: context.theme.colorScheme.surfaceContainerHighest,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timelapse,
                      size: 13,
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ).paddingOnly(right: 4),
                    Text(
                      duration.formatrelative(),
                      style: context.labelSmall?.copyWith(
                        color: context.theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ).paddingAll(6),
              ),
            ),
        ],
      ),
    );
  }
}

abstract class ActivityItem<T extends Activity> implements IRenderable {
  final T activity;

  const ActivityItem(this.activity);

  Future<void> init();

  static Future<ActivityItem> getActionItem(Activity activity) async {
    switch (activity) {
      case final EpisodeActivity activity:
        final item = EpisodeActivityItem(activity);
        await item.init();
        return item;
    }
    throw UnimplementedError();
  }
}

class EpisodeActivityItem extends ActivityItem<EpisodeActivity> {
  Extension? extension;
  EntrySaved? savedentry;
  EpisodeActivityItem(super.activity);

  @override
  Future<void> init() async {
    extension = activity.entry.extension;
    savedentry = await locate<Database>().isSaved(activity.entry);
  }

  @override
  Widget render(BuildContext context) {
    if (extension == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: DionContainer(
          color: context.theme.colorScheme.errorContainer.withValues(
            alpha: 0.08,
          ),
          borderColor: context.theme.colorScheme.error.withValues(alpha: 0.15),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: context.theme.colorScheme.error.withOpacity(0.85),
                  size: 22,
                ).paddingOnly(right: 12),
                Expanded(
                  child: Text(
                    'Unknown extension — content details unavailable',
                    style: context.bodyMedium?.copyWith(
                      color: context.theme.colorScheme.error.withOpacity(0.9),
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final Entry entry = savedentry ?? activity.entry;
    final action = switch (entry.mediaType) {
      MediaType.audio => 'Listened to',
      MediaType.video => 'Watched',
      MediaType.book => 'Read',
      MediaType.comic => 'Read',
      _ => 'Consumed',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Clickable(
        onTap: () {
          context.push('/detail', extra: [entry]);
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: DionContainer(
            color: context.theme.colorScheme.surfaceContainer,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover Image
                if (entry.cover != null) _ActivityCover(entry: entry),

                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          entry.title.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _ActivityMetadata(
                          activity: activity,
                          extensionName: extension!.name,
                        ),
                        const SizedBox(height: 10),

                        // Action & Episode Info
                        Text(
                          (activity.fromepisode == activity.toepisode)
                              ? '$action episode ${activity.fromepisode}'
                              : '$action episodes ${activity.fromepisode}–${activity.toepisode}',
                          style: context.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: context.theme.colorScheme.onSurface
                                .withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityCover extends StatelessWidget {
  final Entry entry;

  const _ActivityCover({required this.entry});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 95,
      height: 135,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DionImage(
            imageUrl: entry.cover?.url,
            boxFit: BoxFit.cover,
            httpHeaders: entry.cover?.header,
          ),
          // Media Type Badge
          Positioned(
            top: 5,
            left: 5,
            child: DionContainer(
              color: context.theme.colorScheme.surfaceContainer,
              child: Icon(
                entry.mediaType.icon,
                size: 11,
                color: context.theme.colorScheme.onSurface,
              ).paddingAll(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityMetadata extends StatelessWidget {
  final EpisodeActivity activity;
  final String extensionName;

  const _ActivityMetadata({
    required this.activity,
    required this.extensionName,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Wrap(
      spacing: width < 500 ? 4 : 12,
      runSpacing: 4,
      children: [
        _buildMetaItem(
          context,
          Icons.timer_outlined,
          activity.duration.formatrelative(
            form: width < 500 ? Abbreviation.full : Abbreviation.none,
          ),
          width,
        ),
        _buildMetaItem(context, Icons.extension_outlined, extensionName, width),
        _buildMetaItem(
          context,
          Icons.access_time,
          activity.time.formatrelative(),
          width,
        ),
      ],
    );
  }

  Widget _buildMetaItem(
    BuildContext context,
    IconData icon,
    String text,
    double width,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: context.theme.colorScheme.onSurface.withOpacity(0.45),
        ).paddingOnly(right: width < 500 ? 2.5 : 4),
        Text(
          text,
          style: context.labelSmall?.copyWith(
            color: context.theme.colorScheme.onSurface.withOpacity(0.5),
            fontSize: 11.5,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

class ActivityView extends StatefulWidget {
  const ActivityView({super.key});

  @override
  State<ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends State<ActivityView> {
  late final DataSourceController<IRenderable> controller;
  Map<DateTime, Duration> activityData = {};
  bool isLoadingChart = true;

  Stream<IRenderable> getActionStream(int index) async* {
    final str = locate<Database>().getActivities(index, 10);
    Activity? last;
    await for (final e in str) {
      if ((last != null && last.time.day != e.time.day) || last == null) {
        final time = e.time.date;
        final dur = await locate<Database>().getActivityDuration(
          time,
          const Duration(days: 1),
        );
        yield DateHeader(e.time, dur);
      }
      yield await ActivityItem.getActionItem(e);
      last = e;
    }
  }

  @override
  void initState() {
    controller = DataSourceController([
      SingleStreamSource((i) => getActionStream(i)),
    ]);
    _loadActivityChart();
    super.initState();
  }

  Future<void> _loadActivityChart() async {
    try {
      final db = locate<Database>();
      final data = await db.getDailyActivityDurations(days: 364);
      if (mounted) {
        setState(() {
          activityData = data;
          isLoadingChart = false;
        });
      }
    } catch (e, stack) {
      logger.e('Failed to load activity chart', error: e, stackTrace: stack);
      if (mounted) {
        setState(() {
          isLoadingChart = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      destination: homedestinations,
      title: const Text('Activity'),
      child: Column(
        children: [
          if (!isLoadingChart)
            ActivityChart(activityData: activityData, weeks: 27)
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: DionProgressBar(),
            ),
          Expanded(
            child: DynamicList(
              showDataSources: false,
              controller: controller,
              itemBuilder: (context, item) => item.render(context),
            ),
          ),
        ],
      ),
    );
  }
}
