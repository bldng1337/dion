import 'dart:ui';

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/downloads.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/service/task.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/time.dart';
import 'package:dionysos/widgets/buttons/clickable.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/container/badge.dart';
import 'package:dionysos/widgets/container/container.dart';

import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:flutter/material.dart' show Colors, FontWeight, Icons;
import 'package:flutter/widgets.dart';
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
        final reverse = entry is EntrySaved
            ? entry.savedSettings.reverse.value
            : false;
        final hideFinishedEpisodes = entry is EntrySaved
            ? entry.savedSettings.hideFinishedEpisodes.value
            : false;
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
      width: 36,
      height: 36,
      child: StreamBuilder(
        stream: locate<DownloadService>().getStatus(episodepath),
        builder: (context, snapshot) {
          return switch (snapshot.data?.status) {
            Status.nodownload => DionContainer(
              child: DionIconbutton(
                icon: const Icon(Icons.download_outlined, size: 18),
                onPressed: () async {
                  await locate<DownloadService>().download([episodepath]);
                },
              ),
            ),
            Status.downloading => ListenableBuilder(
              listenable: snapshot.data!.task!,
              builder: (context, child) =>
                  switch (snapshot.data?.task?.taskstatus) {
                    TaskStatus.idle => Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.pending_outlined,
                        size: 18,
                        color: context.theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    TaskStatus.running || null => Container(
                      padding: const EdgeInsets.all(6),
                      child: DionProgressBar(
                        value: snapshot.data?.task?.progress,
                      ),
                    ),
                    TaskStatus.error => Container(
                      decoration: BoxDecoration(
                        color: context.theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: DionIconbutton(
                        icon: Icon(
                          Icons.error_outline,
                          size: 18,
                          color: context.theme.colorScheme.error,
                        ),
                        onPressed: () {
                          snapshot.data!.task!.clearError();
                          final mngr = locate<TaskManager>();
                          mngr.update();
                        },
                      ),
                    ),
                  },
            ),
            null => Container(
              padding: const EdgeInsets.all(6),
              child: const DionProgressBar(),
            ),
            Status.downloaded => Container(
              decoration: BoxDecoration(
                color: context.theme.colorScheme.primary.withValues(
                  alpha: 0.15,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
              child: DionIconbutton(
                icon: Icon(
                  Icons.check,
                  size: 18,
                  color: context.theme.colorScheme.primary,
                ),
                onPressed: () async {
                  await locate<DownloadService>().deleteEpisode(episodepath);
                },
              ),
            ),
          };
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final epdata = episodepath.data;
    final isWide = context.width >= 600;
    final height = isWide ? 110.0 : 80.0;
    return Stack(
      children: [
        Clickable(
          onLongTap: disabled ? null : onSelect,
          onTap: selection
              ? onSelect
              : disabled
              ? null
              : () => episodepath.go(context),
          child: DionContainer(
            height: height,
            color: isSelected
                ? context.theme.colorScheme.primary.lighten(70)
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (episodepath.episode.cover != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(3),
                      bottomLeft: Radius.circular(3),
                    ),
                    child: DionImage.fromLink(
                      link: episodepath.episode.cover,
                      height: height,
                      boxFit: BoxFit.cover,
                    ),
                  )
                else
                  const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episodepath.episode.name,
                        maxLines: isWide ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            (isWide ? context.titleMedium : context.titleSmall)
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                  letterSpacing: -0.2,
                                  color: epdata.finished
                                      ? context.theme.colorScheme.onSurface
                                            .withValues(alpha: 0.4)
                                      : disabled
                                      ? context.theme.disabledColor
                                      : null,
                                ),
                      ),

                      if (episodepath.episode.timestamp != null)
                        Text(
                          DateTime.tryParse(
                                episodepath.episode.timestamp!,
                              )?.formatrelative() ??
                              '',
                          style: context.labelSmall?.copyWith(
                            letterSpacing: 0.3,
                            fontSize: 11,
                            color: context.theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                          maxLines: 1,
                        ),
                      const Spacer(),
                      if (epdata.finished || epdata.bookmark)
                        Row(
                          children: [
                            if (epdata.bookmark)
                              Icon(
                                Icons.bookmark,
                                size: 14,
                                color: context.theme.colorScheme.primary,
                              ).paddingOnly(right: 2),
                          ],
                        ).paddingOnly(top: 6),
                    ],
                  ).paddingAll(6),
                ),
              ],
            ).paddingOnly(right: 40),
          ),
        ),
        Positioned(right: 6, top: 6, child: buildDownload(context)),
      ],
    ).paddingSymmetric(vertical: 3, horizontal: 6);
  }
}
