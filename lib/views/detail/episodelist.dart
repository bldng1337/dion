import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/downloads.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/service/task.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/time.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';

import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/listtile.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/text_scroll.dart';
import 'package:flutter/material.dart' show Icons, Theme, VisualDensity;
import 'package:flutter/widgets.dart';
import 'package:dionysos/widgets/badge.dart';
import 'package:dionysos/widgets/buttons/clickable.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class EpisodeListSliver extends StatefulWidget {
  final EntryDetailed entry;
  final List<int> selected;
  final Function(int) onSelect;
  final Function(int)? onEnter;
  final Function(int)? onExit;

  const EpisodeListSliver({
    super.key,
    required this.entry,
    required this.selected,
    required this.onSelect,
    this.onExit,
    this.onEnter,
  });

  @override
  State<EpisodeListSliver> createState() => _EpisodeListSliverState();
}

class _EpisodeListSliverState extends State<EpisodeListSliver> {
  @override
  Widget build(BuildContext context) {
    final eplist = widget.entry.episodes;
    if (eplist.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Text('No Episodes', style: context.labelLarge).paddingAll(20),
        ),
      );
    }

    return ListenableBuilder(
      listenable: Listenable.merge([
        if (widget.entry is EntrySaved)
          (widget.entry as EntrySaved).savedSettings.reverse,
        if (widget.entry is EntrySaved)
          (widget.entry as EntrySaved).savedSettings.hideFinishedEpisodes,
        if (widget.entry is EntrySaved)
          (widget.entry as EntrySaved).savedSettings.onlyShowBookmarked,
      ]),
      builder: (context, child) {
        final entry = widget.entry;
        // ignore: avoid_bool_literals_in_conditional_expressions
        final reverse = entry is EntrySaved
            ? entry.savedSettings.reverse.value
            : false;
        // ignore: avoid_bool_literals_in_conditional_expressions
        final hideFinishedEpisodes = entry is EntrySaved
            ? entry.savedSettings.hideFinishedEpisodes.value
            : false;
        // ignore: avoid_bool_literals_in_conditional_expressions
        final onlyShowBookmarked = entry is EntrySaved
            ? entry.savedSettings.onlyShowBookmarked.value
            : false;
        Iterable<(int, Episode)> elist = entry.episodes.indexed;
        if (onlyShowBookmarked) {
          elist = elist.where(
            (e) => entry.getEpisodeData(e.$1).bookmark == true,
          );
        }
        if (hideFinishedEpisodes) {
          elist = elist.where(
            (e) => entry.getEpisodeData(e.$1).finished == false,
          );
        }
        elist = reverse ? elist.toList().reversed : elist;
        final list = elist.toList();

        return SuperSliverList.builder(
          key: PageStorageKey<String>(
            '${entry.boundExtensionId}->${entry.id.uid}',
          ),
          itemCount: list.length,
          itemBuilder: (BuildContext context, int eindex) {
            final index = list[eindex].$1;
            return MouseRegion(
              onEnter: (e) {
                widget.onEnter?.call(index);
              },
              onExit: (e) {
                widget.onExit?.call(index);
              },
              child: EpisodeTile(
                disabled: (entry.extension?.isenabled ?? false) == false,
                episodepath: EpisodePath(entry, index),
                selection: widget.selected.isNotEmpty,
                isSelected: widget.selected.contains(index),
                onSelect: () => widget.onSelect(index),
              ),
            );
          },
        );
      },
    );
  }
}

class EpisodeTile extends StatelessWidget {
  final EpisodePath episodepath;
  final bool isSelected;
  final Function()? onSelect;
  final bool selection;
  final bool disabled;
  const EpisodeTile({
    super.key,
    this.disabled = false,
    required this.episodepath,
    required this.isSelected,
    this.onSelect,
    required this.selection,
  });

  Widget buildDownload(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: StreamBuilder(
        stream: locate<DownloadService>().getStatus(episodepath),
        builder: (context, snapshot) {
          return switch (snapshot.data?.status) {
            Status.nodownload => DionIconbutton(
              icon: const Icon(Icons.download),
              onPressed: () async {
                await locate<DownloadService>().download([episodepath]);
              },
            ),
            Status.downloading => ListenableBuilder(
              listenable: snapshot.data!.task!,
              builder: (context, child) =>
                  switch (snapshot.data?.task?.taskstatus) {
                    TaskStatus.idle => const Icon(Icons.pending_actions),
                    TaskStatus.running || null => DionProgressBar(
                      value: snapshot.data?.task?.progress,
                    ),
                    TaskStatus.error => DionIconbutton(
                      icon: const Icon(Icons.error),
                      onPressed: () {
                        snapshot.data!.task!.clearError();
                        final mngr = locate<TaskManager>();
                        mngr.update();
                      },
                    ),
                  },
            ),
            null => const DionProgressBar(),
            Status.downloaded => DionIconbutton(
              icon: const Icon(Icons.check),
              onPressed: () async {
                await locate<DownloadService>().deleteEpisode(episodepath);
              },
            ),
          };
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final epdata = episodepath.data;
    return Clickable(
      onLongTap: onSelect,
      onTap: selection ? onSelect : () => episodepath.go(context),
      child: DionBadge(
        noPadding: true,
        noMargin: true,
        color: disabled
            ? context.theme.disabledColor.withValues(alpha: 0.1)
            : isSelected
            ? context.theme.colorScheme.primary.withValues(alpha: 0.1)
            : null,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (episodepath.episode.cover != null)
                  DionImage.fromLink(
                    link: episodepath.episode.cover,
                    height: context.width < 600 ? null : 120.0,
                    width: context.width < 600 ? 140 : null,
                  )
                else
                  28.0.widthBox,
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      maxLines: 2,
                      episodepath.episode.name,
                      style:
                          (context.width < 600
                                  ? context.titleSmall
                                  : context.titleMedium)
                              ?.copyWith(
                                color: epdata.finished
                                    ? context.theme.disabledColor
                                    : null,
                              )
                              .copyWith(
                                color:
                                    (episodepath.entry.extension?.isenabled ??
                                        false)
                                    ? null
                                    : context.theme.disabledColor,
                              ),
                    ),
                    if (episodepath.episode.timestamp != null)
                      Text(
                        DateTime.tryParse(
                              episodepath.episode.timestamp!,
                            )?.formatrelative() ??
                            '',
                        style: context.labelSmall?.copyWith(
                          color: context.theme.disabledColor,
                        ),
                      ),
                  ],
                ).paddingAll(5).expanded(),
                if (episodepath.entry is EntrySaved)
                  Center(child: buildDownload(context)).paddingAll(5),
              ],
            ),
            if (epdata.bookmark)
              Icon(
                Icons.bookmark,
                color: context.theme.colorScheme.primary,
              ).paddingAll(5),
          ],
        ),
      ),
    ).paddingAll(3);
  }
}
