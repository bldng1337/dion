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

class EpisodeListSliver extends StatefulWidget {
  final EntryDetailed entry;
  final List<int> selected;
  final Function(int) onSelect;

  const EpisodeListSliver({
    super.key,
    required this.entry,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<EpisodeListSliver> createState() => _EpisodeListSliverState();
}

class _EpisodeListSliverState extends State<EpisodeListSliver> {
  int? hovering;

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

        return SliverList.builder(
          key: PageStorageKey<String>(
            '${entry.boundExtensionId}->${entry.id.uid}',
          ),
          itemCount: list.length,
          itemBuilder: (BuildContext context, int eindex) {
            final index = list[eindex].$1;
            return MouseRegion(
              onEnter: (e) {
                setState(() {
                  hovering = index;
                });
              },
              onExit: (e) {
                setState(() {
                  hovering = null;
                });
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

  @override
  Widget build(BuildContext context) {
    final epdata = episodepath.data;
    return DionListTile(
      disabled: disabled,
      selected: isSelected,
      visualDensity: VisualDensity.comfortable, //TODO: Fix sometime
      onLongTap: onSelect,
      onTap: selection ? onSelect : () => episodepath.go(context),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (episodepath.episode.cover != null)
            DionImage(
              imageUrl: episodepath.episode.cover!.url,
              httpHeaders: episodepath.episode.cover!.header,
              width: 90,
              height: 60,
              boxFit: BoxFit.contain,
            ),
          if (epdata.bookmark)
            Icon(Icons.bookmark, color: context.theme.colorScheme.primary)
          else
            (Theme.of(context).iconTheme.size ?? 24.0).widthBox,
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DionTextScroll(
                episodepath.episode.name,
                style: context.titleMedium,
                // ?.copyWith(
                //   color: epdata.finished
                //       ? context.theme.disabledColor
                //       : null,
                // )
                // .copyWith(
                //   color: (episodepath.entry.extension?.isenabled ?? false)
                //       ? null
                //       : context.theme.disabledColor,
                // )
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
          ).expanded(),
        ],
      ),
      trailing: episodepath.entry is! EntrySaved
          ? null
          : SizedBox(
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
                            TaskStatus.idle => const Icon(
                              Icons.pending_actions,
                            ),
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
                        await locate<DownloadService>().deleteEpisode(
                          episodepath,
                        );
                      },
                    ),
                  };
                },
              ),
            ),
    );
  }
}
