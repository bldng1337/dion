import 'dart:math';

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/entry.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/cancel_token.dart';
import 'package:dionysos/utils/color.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/placeholder.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/time.dart';
import 'package:dionysos/widgets/badge.dart';
import 'package:dionysos/widgets/bounds.dart';
import 'package:dionysos/widgets/buttons/actionbutton.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/context_menu.dart';
import 'package:dionysos/widgets/foldabletext.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/listtile.dart';
import 'package:dionysos/widgets/popupmenu.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/stardisplay.dart';
import 'package:dionysos/widgets/tabbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:text_scroll/text_scroll.dart';
import 'package:url_launcher/url_launcher.dart';

class Detail extends StatefulWidget {
  const Detail({super.key});

  @override
  _DetailState createState() => _DetailState();
}

class _DetailState extends State<Detail> with StateDisposeScopeMixin {
  Entry? entry;
  late CancelToken tok;
  bool refreshing = false;

  Future<void> loadEntry() async {
    try {
      final saved = await locate<Database>().isSaved(entry!);
      if (saved != null) {
        entry = saved;
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e, stack) {
      logger.e('Error checking if entry is saved', error: e, stackTrace: stack);
    }
    try {
      entry = await entry!.toDetailed(token: tok);
      if (mounted) {
        setState(() {});
      }
    } catch (e, stack) {
      logger.e('Error loading entry', error: e, stackTrace: stack);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newentry =
        (GoRouterState.of(context).extra! as List<Object?>)[0]! as Entry;
    setState(() {});
    if (newentry is EntryDetailed || newentry is EntrySaved) {
      entry = newentry;
      return;
    }
    if (entry is EntryDetailed && newentry.id == entry?.id) return;
    if (entry is EntrySaved && newentry.id == entry?.id) return;
    if (!mounted) return;
    entry = newentry;
    if (tok.isDisposed) {
      tok = CancelToken()..disposedBy(scope);
    }
    loadEntry();
  }

  @override
  void initState() {
    super.initState();
    tok = CancelToken()..disposedBy(scope);
  }

  @override
  Widget build(BuildContext context) {
    if (entry == null) {
      return const NavScaff(child: Center(child: CircularProgressIndicator()));
    }
    final actions = [
      if (entry is EntrySaved)
        DionIconbutton(
          onPressed: () async {
            refreshing = true;
            if (mounted) {
              setState(() {});
            }
            final e = await (entry! as EntrySaved).refresh();
            if (mounted) {
              entry = e;
              refreshing = false;
              setState(() {});
            }
          },
          icon: refreshing
              ? const CircularProgressIndicator()
              : const Icon(Icons.refresh),
        ),
      if (entry is EntryDetailed)
        DionIconbutton(
          onPressed: () {
            launchUrl(Uri.parse(entry!.url));
          },
          icon: const Icon(Icons.open_in_browser),
        ),
    ];
    if (context.width < 800) {
      return NavScaff(
        actions: actions,
        floatingActionButton: entry is EntrySaved
            ? ActionButton(
                onPressed: () {
                  EpisodePath(
                    entry! as EntryDetailed,
                    (entry! as EntrySaved).episode,
                    (entry! as EntrySaved).latestEpisode,
                  ).go(context);
                },
                child: const Icon(Icons.play_arrow),
              )
            : null,
        title: TextScroll(entry?.title ?? ''),
        child: DionTabBar(
          tabs: [
            DionTab(
              tab: const TextScroll('Info'),
              child: EntryInfo(entry: entry!),
            ),
            if (entry is EntryDetailed)
              DionTab(
                tab: const TextScroll('Episodes'),
                child: EpisodeListUI(entry: entry! as EntryDetailed),
              ),
          ],
        ),
      );
    }
    return NavScaff(
      actions: actions,
      floatingActionButton: entry is EntrySaved
          ? ActionButton(
              onPressed: () {
                EpisodePath(
                  entry! as EntryDetailed,
                  (entry! as EntrySaved).episode,
                  (entry! as EntrySaved).latestEpisode,
                ).go(context);
              },
              child: const Icon(Icons.play_arrow),
            )
          : null,
      title: TextScroll(entry?.title ?? ''),
      child: SizedBox(
        width: context.width - 200,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: context.width / 2,
              child: EntryInfo(entry: entry!),
            ).expanded(),
            isEntryDetailed(
              context: context,
              entry: entry!,
              isdetailed: (entry) => EpisodeListUI(
                entry: entry,
              ),
            ).expanded(),
          ],
        ),
      ),
    );
  }
}

Widget isEntryDetailed({
  required BuildContext context,
  required Entry entry,
  required Widget Function(EntryDetailed e) isdetailed,
  Widget Function()? isnt,
  bool shimmer = true,
}) {
  isnt ??= () => Container(
        color: Colors.white,
      );
  if (entry is EntryDetailed) {
    return isdetailed(entry);
  }
  if (!shimmer) {
    return isnt();
  }
  return BoundsWidget(
    child: isnt(),
  ).applyShimmer(
    highlightColor: context.backgroundColor.lighten(20),
    baseColor: context.backgroundColor,
  );
}

class EntryInfo extends StatelessWidget {
  final Entry entry;
  const EntryInfo({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 3, left: 7, right: 7),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            DionImage(
              alignment: Alignment.topCenter,
              imageUrl: entry.cover,
              width: 140,
              height: 220,
            ).paddingAll(3),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextScroll(
                  entry.title,
                  style: context.headlineMedium,
                  pauseBetween: 1.seconds,
                ),
                if (entry.author != null && entry.author!.isNotEmpty)
                  TextScroll(
                    'by ${(entry.author != null && entry.author!.isNotEmpty) ? entry.author!.map(
                          (e) => e.trim().replaceAll('\n', ''),
                        ).reduce((a, b) => '$a • $b') : 'Unkown author'}',
                    style: context.labelLarge,
                    pauseBetween: 1.seconds,
                  ),
                Row(
                  children: [
                    DionImage(
                      imageUrl: entry.extension.data.icon,
                      width: 15,
                      height: 15,
                      errorWidget: const Icon(
                        Icons.image,
                        size: 20,
                      ),
                    ).paddingOnly(right: 5),
                    TextScroll(
                      entry.extension.data.name,
                      style: context.bodyMedium,
                      pauseBetween: 1.seconds,
                    ),
                    const Text(' • '),
                    isEntryDetailed(
                      context: context,
                      entry: entry,
                      isdetailed: (entry) => Text(
                        entry.status.asString(),
                        style: context.bodyMedium,
                      ),
                      isnt: () => Text(
                        'Releasing',
                        style: context.bodyMedium,
                      ),
                    ),
                  ],
                ),
                if (entry.rating != null)
                  Stardisplay(
                    width: 20,
                    height: 20,
                    fill: entry.rating!,
                    color: Colors.yellow[500]!,
                  ),
                if (entry.views != null)
                  Text(
                    NumberFormat.compact().format(entry.views),
                    style: context.bodyMedium,
                  ),
              ],
            ).paddingAll(5).expanded(),
          ],
        ),
        isEntryDetailed(
          context: context,
          entry: entry,
          isdetailed: (entry) => DionIconbutton(
            icon: Icon(
              entry.inLibrary ? Icons.library_books : Icons.library_add,
              size: 30,
            ),
            onPressed: () {
              if (entry.inLibrary) {
                (entry as EntrySaved).delete().then((e) {
                  if (context.mounted) {
                    GoRouter.of(context).replace('/detail', extra: [e]);
                  }
                });
              } else {
                entry.toSaved().then((e) {
                  if (context.mounted) {
                    GoRouter.of(context).replace('/detail', extra: [e]);
                  }
                });
              }
            },
          ),
          isnt: () => DionIconbutton(
            icon: Icon(
              entry.inLibrary ? Icons.library_books : Icons.library_add,
              size: 30,
            ),
          ),
          shimmer: false,
        ),
        SizedBox(
          height: 40,
          child: isEntryDetailed(
            context: context,
            entry: entry,
            isdetailed: (entry) => ListView(
              shrinkWrap: true,
              scrollDirection: Axis.horizontal,
              children: entry.genres
                      ?.map(
                        (e) => DionBadge(
                          color: getColor(e),
                          child: Text(e),
                        ),
                      )
                      .toList() ??
                  [],
            ),
            isnt: () => Row(
              children: getWords(4)
                  .map(
                    (e) => DionBadge(
                      child: Text(e),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        isEntryDetailed(
          context: context,
          entry: entry,
          isdetailed: (entry) => Foldabletext(
            maxLines: 7,
            entry.description.trim(),
            style: context.bodyMedium,
          ),
          isnt: () => Text(
            maxLines: 7,
            getText(70),
            style: context.bodyMedium,
          ),
        ).paddingOnly(top: 7),
      ],
    );
  }
}

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
      return Center(
        child: Text(
          'No Episodes',
          style: context.labelLarge,
        ),
      );
    }
    return Column(
      children: [
        Row(
          children: [
            DionPopupMenu(
              items: eplist.indexed
                  .map(
                    (ep) => DionPopupMenuItem(
                      label: Text('${ep.$2.title} - ${ep.$2.episodes.length}'),
                      onTap: () {
                        if (mounted) {
                          setState(() {
                            selected = ep.$1;
                            (widget.entry as EntrySaved).episode = selected;
                            (widget.entry as EntrySaved).save();
                          });
                        }
                      },
                    ),
                  )
                  .toList(),
              child: Row(
                children: [
                  const Icon(Icons.folder),
                  Text(
                    '${eplist[selected].title} - ${eplist[selected].episodes.length} Episodes',
                    style: context.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        EpList(entry: widget.entry, eplistindex: selected).expanded(),
      ],
    );
  }
}

class EpList extends StatefulWidget {
  final EntryDetailed entry;
  final int eplistindex;

  EpisodeList get elist => entry.episodes[eplistindex];
  const EpList({super.key, required this.entry, required this.eplistindex});

  @override
  _EpListState createState() => _EpListState();
}

class _EpListState extends State<EpList> with StateDisposeScopeMixin {
  late List<int> selected;
  late ScrollController controller;
  int? last;

  @override
  void initState() {
    selected = List.empty(growable: true);
    controller = ScrollController()..disposedBy(scope);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ContextMenu(
      active: selected.isNotEmpty && widget.entry is EntrySaved,
      contextItems: [
        ContextMenuItem(
          label: 'Mark as watched',
          onTap: () async {
            for (final int i in selected) {
              final data = (widget.entry as EntrySaved).getEpisodeData(i);
              data.finished = true;
            }
            selected.clear();
            await (widget.entry as EntrySaved).save();
          },
        ),
        ContextMenuItem(
          label: 'Mark as unwatched',
          onTap: () async {
            for (final int i in selected) {
              final data = (widget.entry as EntrySaved).getEpisodeData(i);
              data.finished = false;
            }
            selected.clear();
            await (widget.entry as EntrySaved).save();
            setState(() {});
          },
        ),
        ContextMenuItem(
          label: 'Mark to this episode',
          onTap: () async {
            for (int i = 0; i <= selected.reduce((a, b) => max(a, b)); i++) {
              final data = (widget.entry as EntrySaved).getEpisodeData(i);
              data.finished = true;
            }
            selected.clear();
            await (widget.entry as EntrySaved).save();
            setState(() {});
          },
        ),
      ],
      child: ListView.builder(
        controller: controller,
        padding: EdgeInsets.zero,
        itemCount: widget.elist.episodes.length,
        itemBuilder: (BuildContext context, int index) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          // onSecondaryTap: () {
          //   logger.i('Secondary tap up $index');
          //   last = index;
          // },
          child: EpisodeTile(
            episodepath: EpisodePath(widget.entry, widget.eplistindex, index),
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
        ),
      ),
    );
  }
}

class EpisodeTile extends StatelessWidget {
  final EpisodePath episodepath;
  final bool isSelected;
  final Function()? onSelect;
  final bool selection;
  const EpisodeTile({
    super.key,
    required this.episodepath,
    required this.isSelected,
    this.onSelect,
    required this.selection,
  });

  @override
  Widget build(BuildContext context) {
    final epdata = episodepath.data;
    return DionListTile(
      selected: isSelected,
      visualDensity: VisualDensity.comfortable,
      onLongTap: onSelect,
      onTap: selection ? onSelect : () => episodepath.go(context),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (episodepath.episode.cover != null &&
              episodepath.episode.cover!.isNotEmpty)
            DionImage(
              imageUrl: episodepath.episode.cover,
              httpHeaders: episodepath.episode.coverHeader,
              width: 90,
              height: 60,
              boxFit: BoxFit.contain,
            ),
          if (epdata.bookmark)
            Icon(
              Icons.bookmark,
              color: context.theme.colorScheme.primary,
            )
          else
            (Theme.of(context).iconTheme.size ?? 24.0).widthBox,
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextScroll(
                episodepath.episode.name,
                style: context.titleMedium?.copyWith(
                  color: epdata.finished ? context.theme.disabledColor : null,
                ),
              ),
              if (episodepath.episode.timestamp != null)
                Text(
                  DateTime.tryParse(episodepath.episode.timestamp!)
                          ?.formatrelative() ??
                      '',
                  style: context.labelSmall?.copyWith(
                    color: context.theme.disabledColor,
                  ),
                ),
            ],
          ).expanded(),
        ],
      ),
    );
  }
}

class CustomUI extends StatelessWidget {
  const CustomUI({super.key});

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
