import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/activity.dart';
import 'package:dionysos/data/entry.dart';
import 'package:dionysos/routes.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/time.dart';
import 'package:dionysos/widgets/badge.dart';
import 'package:dionysos/widgets/buttons/clickable.dart';
import 'package:dionysos/widgets/dynamic_grid.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/listtile.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moment_dart/moment_dart.dart';

abstract class IRenderable {
  Widget render(BuildContext context);
}

class Divider implements IRenderable {
  final DateTime date;
  final Duration duration;
  const Divider(this.date, this.duration);

  @override
  Widget render(BuildContext context) {
    return DionListTile(
      title: Text('  ${date.toDateString()}'),
      trailing: Text(
        duration.formatrelative(),
        style: context.labelSmall!.copyWith(color: context.theme.disabledColor),
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
    if (activity.entry == null) return;
    extension = activity.entry!.extension;
    savedentry = await locate<Database>().isSaved(activity.entry!);
  }

  @override
  Widget render(BuildContext context) {
    if (extension == null) {
      return Clickable(
        child: DionBadge(
          color: context.theme.scaffoldBackgroundColor.lighten(5),
          child: SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error,
                  color: Colors.redAccent,
                ).paddingOnly(right: 5),
                const Text('Unkown Extension').paddingOnly(right: 5),
              ],
            ),
          ).paddingAll(5),
        ),
      ).paddingOnly(bottom: 5);
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
        context.push(
          '/detail',
          extra: [entry],
        );
      },
      child: DionBadge(
        color: context.theme.scaffoldBackgroundColor.lighten(5),
        child: SizedBox(
          height: 160,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DionImage(
                imageUrl: entry.cover,
                boxFit: BoxFit.contain,
                alignment: Alignment.center,
                httpHeaders: entry.coverHeader,
                width: 120,
                height: 160,
              ).paddingOnly(right: 5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title.trim(),
                      maxLines: 1,
                      style: context.titleLarge,
                    ),
                    Expanded(
                      child: Text(
                        (activity.fromepisode == activity.toepisode)
                            ? '$action episode ${activity.fromepisode}'
                            : '$action episode ${activity.fromepisode} - ${activity.toepisode}',
                        style: context.bodyMedium,
                      ),
                    ),
                    Text(
                      '$action for ${activity.duration.formatrelative()}',
                      style: context.labelSmall!
                          .copyWith(color: context.theme.disabledColor),
                    ),
                  ],
                ).paddingOnly(left: 5),
              ),
              Text(
                activity.time.formatrelative(),
                style: context.labelSmall!
                    .copyWith(color: context.theme.disabledColor),
              ).paddingAll(15),
            ],
          ),
        ).paddingAll(5),
      ),
    ).paddingOnly(bottom: 5);
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
    final str = locate<Database>().getActivityStream(index, 10);
    Activity? last;
    await for (final e in str) {
      if ((last != null && last.time.day != e.time.day) || last == null) {
        final time = e.time.date;
        final dur = await locate<Database>()
            .getActivityDuration(time, const Duration(days: 1));
        yield Divider(e.time, dur);
      }
      yield await ActivityItem.getActionItem(e);
      last = e;
    }
  }

  @override
  void initState() {
    controller = DataSourceController(
      [
        SingleStreamSource(
          (i) => getActionStream(i),
        ),
      ],
    );
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
