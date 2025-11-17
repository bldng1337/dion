import 'dart:math';

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
import 'package:dionysos/widgets/context_menu.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/listtile.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/text_scroll.dart';
import 'package:flutter/material.dart' show Icons, Theme, VisualDensity;
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:url_launcher/url_launcher.dart';

class EpisodeListUI extends StatefulWidget {
  final EntryDetailed entry;
  const EpisodeListUI({super.key, required this.entry});

  @override
  State<EpisodeListUI> createState() => _EpisodeListUIState();
}

class _EpisodeListUIState extends State<EpisodeListUI> {
  int selected = 0;
  @override
  void initState() {
    if (widget.entry is EntrySaved) {
      selected = (widget.entry as EntrySaved).episode;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final eplist = widget.entry.episodes;
    if (eplist.isEmpty) {
      return Center(child: Text('No Episodes', style: context.labelLarge));
    }
    return Column(children: [EpList(entry: widget.entry).expanded()]);
  }
}

class EpList extends StatefulWidget {
  final EntryDetailed entry;

  List<Episode> get elist => entry.episodes;
  const EpList({super.key, required this.entry});

  @override
  _EpListState createState() => _EpListState();
}

class _EpListState extends State<EpList> with StateDisposeScopeMixin {
  late List<int> selected;
  int? hovering;
  late ScrollController controller;
  int? last;

  @override
  void initState() {
    selected = List.empty(growable: true);
    controller = ScrollController()..disposedBy(scope);
    super.initState();
  }

  List<int> get selection {
    if (selected.isNotEmpty) return selected;
    if (hovering != null) return [hovering!];
    return List.empty();
  }

  List<ContextMenuItem> get contextItems => [
    ContextMenuItem(
      label: 'Bookmark',
      onTap: () async {
        for (final int i in selection) {
          final data = (widget.entry as EntrySaved).getEpisodeData(i);
          data.bookmark = true;
        }
        selected.clear();
        setState(() {});
        await (widget.entry as EntrySaved).save();
      },
    ),
    ContextMenuItem(
      label: 'Remove Bookmark',
      onTap: () async {
        for (final int i in selection) {
          final data = (widget.entry as EntrySaved).getEpisodeData(i);
          data.bookmark = false;
        }
        selected.clear();
        setState(() {});
        await (widget.entry as EntrySaved).save();
      },
    ),
    ContextMenuItem(
      label: 'Mark as finished',
      onTap: () async {
        for (final int i in selection) {
          final data = (widget.entry as EntrySaved).getEpisodeData(i);
          data.finished = true;
        }
        selected.clear();
        setState(() {});
        await (widget.entry as EntrySaved).save();
      },
    ),
    ContextMenuItem(
      label: 'Mark as unfinished',
      onTap: () async {
        for (final int i in selection) {
          final data = (widget.entry as EntrySaved).getEpisodeData(i);
          data.finished = false;
          data.progress = null;
        }
        selected.clear();
        setState(() {});
        await (widget.entry as EntrySaved).save();
      },
    ),
    ContextMenuItem(
      label: 'Download',
      onTap: () async {
        final download = locate<DownloadService>();
        await download.download(
          selection.map((index) => EpisodePath(widget.entry, index)),
        );
        selected.clear();
        setState(() {});
      },
    ),
    ContextMenuItem(
      label: 'Delete Download',
      onTap: () async {
        final download = locate<DownloadService>();
        await download.deleteEpisodes(
          selection.map((index) => EpisodePath(widget.entry, index)),
        );
        selected.clear();
        setState(() {});
      },
    ),
    if (selection.length == 1) ...[
      ContextMenuItem(
        label: 'Open in Browser',
        onTap: () async {
          await launchUrl(
            Uri.parse(widget.entry.episodes[selection.first].url),
          );
        },
      ),
    ],
    ContextMenuItem(
      label: 'Select to this episode',
      onTap: () async {
        final index = selection.reduce((a, b) => max(a, b)) + 1;
        selected.clear();
        selected.addAll(Iterable.generate(index, (index) => index));
        setState(() {});
      },
    ),
    if (widget.entry is EntrySaved)
      ContextMenuItem(
        label: 'Select finished episodes',
        onTap: () async {
          selected.clear();
          selected.addAll(
            widget.entry.episodes.indexed
                .where(
                  (e) => (widget.entry as EntrySaved)
                      .getEpisodeData(e.$1)
                      .finished,
                )
                .map((e) => e.$1)
                .toList(),
          );
          setState(() {});
        },
      ),
    if (widget.entry is EntrySaved)
      ContextMenuItem(
        label: 'Select unfinished episodes',
        onTap: () async {
          selected.clear();
          selected.addAll(
            widget.entry.episodes.indexed
                .where(
                  (e) => !(widget.entry as EntrySaved)
                      .getEpisodeData(e.$1)
                      .finished,
                )
                .map((e) => e.$1)
                .toList(),
          );
          setState(() {});
        },
      ),
    ContextMenuItem(
      label: 'Select All',
      onTap: () async {
        selected.clear();
        selected.addAll(
          widget.entry.episodes.indexed.map((e) => e.$1).toList(),
        );
        setState(() {});
      },
    ),
    if (selected.isNotEmpty)
      ContextMenuItem(
        label: 'Clear Selection',
        onTap: () async {
          selected.clear();
          setState(() {});
        },
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return ContextMenu(
      selectionActive: selected.isNotEmpty,
      active: entry is EntrySaved,
      contextItems: contextItems,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          if (entry is EntrySaved) entry.savedSettings.reverse,
          if (entry is EntrySaved) entry.savedSettings.hideFinishedEpisodes,
          if (entry is EntrySaved) entry.savedSettings.onlyShowBookmarked,
        ]),
        builder: (context, child) {
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
          Iterable<(int, Episode)> elist = widget.elist.indexed;
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
          return ListView.builder(
            key: PageStorageKey<String>(
              '${entry.boundExtensionId}->${entry.id}',
            ),
            controller: controller,
            prototypeItem: EpisodeTile(
              episodepath: EpisodePath(entry, 0),
              selection: false,
              isSelected: false,
              onSelect: () {},
            ),
            padding: EdgeInsets.zero,
            itemCount: list.length,
            itemBuilder: (BuildContext context, int eindex) {
              final index = list[eindex].$1;
              return MouseRegion(
                onEnter: (e) {
                  hovering = index;
                },
                child: EpisodeTile(
                  disabled: (entry.extension?.isenabled ?? false) == false,
                  episodepath: EpisodePath(entry, index),
                  selection: selected.isNotEmpty,
                  isSelected: selected.contains(index),
                  onSelect: () {
                    if (selected.contains(index)) {
                      selected.remove(index);
                    } else {
                      selected.add(index);
                    }
                    setState(() {});
                  },
                ),
              );
            },
          );
        },
      ),
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
                style: context.titleMedium
                    ?.copyWith(
                      color: epdata.finished
                          ? context.theme.disabledColor
                          : null,
                    )
                    .copyWith(
                      color: (episodepath.entry.extension?.isenabled ?? false)
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
