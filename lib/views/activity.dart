import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/activity/activity.dart';
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/routes.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/media_type.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/time.dart';
import 'package:dionysos/widgets/badge.dart';
import 'package:dionysos/widgets/buttons/clickable.dart';
import 'package:dionysos/widgets/dynamic_grid.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/listtile.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/material.dart' show Colors, Icons, BorderRadius;
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
    // A more prominent date header with an icon and a small duration badge.
    return DionListTile(
      title: Row(
        children: [
          const Icon(Icons.calendar_today, size: 18).paddingOnly(right: 8),
          Text(
            date.toDateString(),
            style: context.titleMedium!.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      subtitle: Text(
        'Activities',
        style: context.bodySmall!.copyWith(color: context.theme.disabledColor),
      ),
      trailing: DionBadge(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timelapse, size: 14).paddingOnly(right: 6),
            Text(duration.formatrelative(), style: context.labelSmall),
          ],
        ).paddingSymmetric(horizontal: 8, vertical: 6),
      ),
    ).paddingOnly(bottom: 6);
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
    if (activity.entry == null) return;
    extension = activity.entry!.extension;
    savedentry = await locate<Database>().isSaved(activity.entry!);
  }

  @override
  Widget render(BuildContext context) {
    if (extension == null) {
      return Clickable(
        child: DionBadge(
          child: Container(
            height: 100,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 28,
                ).paddingOnly(right: 8),
                const Expanded(
                  child: Text(
                    'Unknown extension — content details unavailable',
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ).paddingOnly(bottom: 8);
    }

    final Entry entry = savedentry ?? activity.entry!;
    final action = switch (entry.mediaType) {
      MediaType.audio => 'Listened to',
      MediaType.video => 'Watched',
      MediaType.book => 'Read',
      MediaType.comic => 'Read',
      _ => 'Consumed',
    };

    return Clickable(
      onTap: () {
        context.push('/detail', extra: [entry]);
      },
      child: DionBadge(
        child: Container(
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minHeight: 120, maxHeight: 200),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.cover != null)
                Stack(
                  children: [
                    DionImage(
                      imageUrl: entry.cover?.url,
                      boxFit: BoxFit.cover,
                      alignment: Alignment.center,
                      httpHeaders: entry.cover?.header,
                    ),
                    Row(
                      children: [
                        Icon(entry.mediaType.icon, size: 14),
                        if (savedentry != null)
                          const Icon(Icons.bookmark, size: 14),
                      ].map((e) => DionBadge(child: e)).toList(),
                    ),
                  ],
                ).paddingOnly(right: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.titleLarge!.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.timer,
                          size: 14,
                          color: context.theme.disabledColor,
                        ).paddingOnly(right: 3),
                        Text(
                          activity.duration.formatrelative(),
                          style: context.labelSmall!.copyWith(
                            color: context.theme.disabledColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.extension,
                          size: 14,
                          color: context.theme.disabledColor,
                        ).paddingOnly(right: 3),
                        Text(
                          extension!.name,
                          style: context.labelSmall!.copyWith(
                            color: context.theme.disabledColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.calendar_month,
                          size: 14,
                          color: context.theme.disabledColor,
                        ).paddingOnly(right: 3),
                        Text(
                          activity.time.formatrelative(),
                          style: context.labelSmall!.copyWith(
                            color: context.theme.disabledColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (activity.fromepisode == activity.toepisode)
                          ? '$action episode ${activity.fromepisode}'
                          : '$action episodes ${activity.fromepisode}–${activity.toepisode}',
                      style: context.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).paddingOnly(bottom: 10);
  }
}

class ActivityView extends StatefulWidget {
  const ActivityView({super.key});

  @override
  State<ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends State<ActivityView> {
  late final DataSourceController<IRenderable> controller;

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
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      destination: homedestinations,
      child: DynamicList(
        showDataSources: false,
        controller: controller,
        itemBuilder: (context, item) => item.render(context),
      ),
    );
  }
}
