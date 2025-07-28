import 'dart:math';

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/entry.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/downloads.dart';
import 'package:dionysos/service/source_extension.dart' hide DropdownItem;
import 'package:dionysos/service/task.dart';
import 'package:dionysos/utils/cancel_token.dart';
import 'package:dionysos/utils/color.dart';
import 'package:dionysos/utils/extension_setting.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/placeholder.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/settings.dart';
import 'package:dionysos/utils/time.dart';
import 'package:dionysos/widgets/badge.dart';
import 'package:dionysos/widgets/bounds.dart';
import 'package:dionysos/widgets/buttons/actionbutton.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/card.dart';
import 'package:dionysos/widgets/columnrow.dart';
import 'package:dionysos/widgets/context_menu.dart';
import 'package:dionysos/widgets/dropdown/multi_dropdown.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/foldabletext.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/listtile.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/stardisplay.dart';
import 'package:dionysos/widgets/tabbar.dart';
import 'package:dionysos/widgets/text_scroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class Detail extends StatefulWidget {
  const Detail({super.key});

  @override
  _DetailState createState() => _DetailState();
}

class _DetailState extends State<Detail> with StateDisposeScopeMixin {
  Entry? entry;
  late CancelToken tok;
  Object? error;
  StackTrace? errstack;

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
      error = e;
      if (mounted) {
        setState(() {});
      }
    }
    try {
      entry = await entry!.toDetailed(token: tok);
      if (mounted) {
        setState(() {});
      }
    } catch (e, stack) {
      logger.e('Error loading entry', error: e, stackTrace: stack);
      error = e;
      if (mounted) {
        setState(() {});
      }
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
    if (error != null) {
      return NavScaff(
        child: ErrorDisplay(e: error, s: errstack),
      );
    }
    if (entry == null) {
      return const NavScaff(child: Center(child: CircularProgressIndicator()));
    }
    if (entry is EntryDetailed) {
      return ListenableBuilder(
        listenable: entry!.extension,
        builder: (context, child) => buildDetailScreen(context),
      );
    }
    return buildDetailScreen(context);
  }

  Widget buildDetailScreen(BuildContext context) {
    final actions = [
      if (entry is EntrySaved && entry!.extension.isenabled)
        DionIconbutton(
          onPressed: () {
            showSettingPopup(context, entry! as EntrySaved);
          },
          icon: const Icon(Icons.settings),
        ),
      if (entry is EntrySaved && entry!.extension.isenabled)
        DionIconbutton(
          onPressed: () async {
            try {
              if (tok.isDisposed) {
                tok = CancelToken()..disposedBy(scope);
              }
              final e = await (entry! as EntrySaved).refresh(token: tok);
              entry = e;
              if (mounted) {
                setState(() {});
              }
            } catch (e, stack) {
              error = e;
              errstack = stack;
              if (mounted) {
                setState(() {});
              }
            }
          },
          icon: const Icon(Icons.refresh),
        ),
      if (entry is EntryDetailed)
        DionIconbutton(
          onPressed: () {
            try {
              launchUrl(Uri.parse(entry!.url));
            } catch (e) {
              error = e;
              if (mounted) {
                setState(() {});
              }
            }
          },
          icon: const Icon(Icons.open_in_browser),
        ),
    ];
    if (context.width < 950) {
      return NavScaff(
        actions: actions,
        floatingActionButton:
            (entry is EntrySaved && entry!.extension.isenabled)
            ? ActionButton(
                onPressed: () {
                  EpisodePath(
                    entry! as EntryDetailed,
                    min(
                      (entry! as EntrySaved).latestEpisode,
                      (entry! as EntrySaved).episodes.length - 1,
                    ),
                  ).go(context);
                },
                child: const Icon(Icons.play_arrow),
              )
            : null,
        title: DionTextScroll(entry?.title ?? ''),
        child: DionTabBar(
          tabs: [
            DionTab(
              tab: const DionTextScroll('Info'),
              child: EntryInfo(entry: entry!),
            ),
            if (entry is EntryDetailed)
              DionTab(
                tab: const DionTextScroll('Episodes'),
                child: EpisodeListUI(entry: entry! as EntryDetailed),
              ),
          ],
        ),
      );
    }
    return NavScaff(
      actions: actions,
      floatingActionButton: (entry is EntrySaved && entry!.extension.isenabled)
          ? ActionButton(
              onPressed: () {
                EpisodePath(
                  entry! as EntryDetailed,
                  min(
                    (entry! as EntrySaved).latestEpisode,
                    (entry! as EntrySaved).episodes.length - 1,
                  ),
                ).go(context);
              },
              child: const Icon(Icons.play_arrow),
            )
          : null,
      title: DionTextScroll(entry?.title ?? ''),
      child: SizedBox(
        width: context.width - 200,
        child: Row(
          children: [
            SizedBox(
              width: context.width / 2,
              child: EntryInfo(entry: entry!),
            ),
            isEntryDetailed(
              context: context,
              entry: entry!,
              isdetailed: (entry) => EpisodeListUI(entry: entry),
            ).expanded(),
          ],
        ),
      ),
    );
  }
}

void showSettingPopup(BuildContext context, EntrySaved entry) {
  showAdaptiveDialog(
    context: context,
    builder: (context) => Dialog(child: SettingsPopup(entry: entry)),
  );
}

class SettingsPopup extends StatefulWidget {
  final EntrySaved entry;
  const SettingsPopup({super.key, required this.entry});

  @override
  State<SettingsPopup> createState() => _SettingsPopupState();
}

class _SettingsPopupState extends State<SettingsPopup>
    with StateDisposeScopeMixin {
  MultiDropdownController<Category>? controller;
  late final List<Setting<dynamic, EntrySettingMetaData<dynamic>>> settings;
  @override
  void initState() {
    super.initState();
    final db = locate<Database>();
    settings = widget.entry.settings;
    scope.addDispose(() {
      widget.entry.save();
    });
    db.getCategories().then((categories) {
      if (categories.isEmpty) return;
      controller = MultiDropdownController<Category>();
      controller!.setItems(
        categories.map((e) => MultiDropdownItem(label: e.name, value: e)),
      );
      controller!.selectWhere((e) => widget.entry.categories.contains(e.value));
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Settings'),
          if (controller != null)
            DionMultiDropdown(
              defaultItem: const Text('Choose a category'),
              controller: controller,
              onSelectionChange: (selection) async {
                widget.entry.categories = selection;
                await widget.entry.save();
              },
            ).paddingAll(10),
          const Text('Extension Settings'),
          for (final setting in settings)
            ExtensionSettingView(setting: setting),
        ],
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
  isnt ??= () => Container(color: Colors.white);
  if (entry is EntryDetailed) {
    return isdetailed(entry);
  }
  if (!shimmer) {
    return isnt();
  }
  return BoundsWidget(child: isnt()).applyShimmer(
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
      padding: const EdgeInsets.only(top: 6, left: 5, right: 7),
      children: [
        if (entry is EntryDetailed &&
            !(entry as EntryDetailed).extension.isenabled)
          ColoredBox(
            color: context.theme.colorScheme.errorContainer,
            child: Row(
              children: [
                Text('Warning: Extension Disabled', style: context.bodyLarge),
                const Spacer(),
                DionTextbutton(
                  child: const Text('Enable'),
                  onPressed: () async {
                    (entry as EntryDetailed).extension.enable();
                  },
                ),
              ],
            ).paddingAll(3),
          ).paddingAll(5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: DionImage(
                alignment: Alignment.center,
                imageUrl: entry.cover,
                borderRadius: BorderRadius.circular(3),
                filterQuality: FilterQuality.high,
                hasPopup: true,
                width: (context.width > 500) ? 200 : 150,
              ).paddingAll(3),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: (context.width > 950)
                      ? context.headlineLarge
                      : context.headlineSmall,
                  // pauseBetween: 1.seconds,
                ),
                if (entry.author != null && entry.author!.isNotEmpty)
                  DionTextScroll(
                    'by ${(entry.author != null && entry.author!.isNotEmpty) ? entry.author!.map((e) => e.trim().replaceAll('\n', '')).reduce((a, b) => '$a • $b') : 'Unkown author'}',
                    style: context.labelLarge?.copyWith(color: Colors.grey),
                  ),
                Row(
                  children: [
                    DionImage(
                      imageUrl: entry.extension.data.icon,
                      width: 15,
                      height: 15,
                      errorWidget: const Icon(Icons.image, size: 20),
                    ).paddingOnly(right: 5),
                    DionTextScroll(
                      entry.extension.data.name,
                      style: context.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                    Text(
                      ' • ',
                      style: context.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                    isEntryDetailed(
                      context: context,
                      entry: entry,
                      isdetailed: (entry) => Text(
                        entry.status.asString(),
                        style: context.bodyMedium?.copyWith(color: Colors.grey),
                      ),
                      isnt: () => Text('Releasing', style: context.bodyMedium),
                    ),
                  ],
                ),
                20.0.heightBox,
                SizedBox(
                  height: 40,
                  child: isEntryDetailed(
                    context: context,
                    entry: entry,
                    isdetailed: (entry) => ListView(
                      shrinkWrap: true,
                      scrollDirection: Axis.horizontal,
                      children:
                          entry.genres
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
                      children: getWords(
                        4,
                      ).map((e) => DionBadge(child: Text(e))).toList(),
                    ),
                  ),
                ),
                if (entry.rating != null || entry.views != null)
                  DionBadge(
                    color: context.theme.primaryColor.lighten(5),
                    child: ColumnRow(
                      isRow: context.width > 950,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (entry.rating != null)
                          Stardisplay(
                            width: 25,
                            height: 25,
                            fill: entry.rating!,
                            color: Colors.yellow[500]!,
                          ).paddingOnly(right: 5),
                        RichText(
                          text: TextSpan(
                            children: [
                              if (entry.rating != null && context.width > 1200)
                                TextSpan(
                                  text:
                                      '${(entry.rating! * 5).toStringAsFixed(2)} Stars (',
                                  style: context.bodyLarge,
                                ),
                              if (entry.views != null)
                                TextSpan(
                                  text:
                                      '${NumberFormat.compact().format(entry.views)} Views',
                                  style: context.bodyLarge,
                                ),
                              if (entry.rating != null && context.width > 1200)
                                TextSpan(text: ')', style: context.bodyLarge),
                            ],
                          ),
                        ),
                      ],
                    ).paddingAll(5),
                  ).paddingOnly(top: 5, bottom: 5),
              ],
            ).paddingOnly(bottom: 5, left: 5).expanded(),
          ],
        ),
        isEntryDetailed(
          context: context,
          entry: entry,
          isdetailed: (entry) => DionIconbutton(
            icon: Icon(
              entry is EntrySaved ? Icons.library_books : Icons.library_add,
              size: 30,
            ),
            onPressed: () async {
              if (entry is EntrySaved) {
                final entrydetailed = await entry.delete();
                if (context.mounted) {
                  GoRouter.of(
                    context,
                  ).replace('/detail', extra: [entrydetailed]);
                }
              } else {
                final saved = await entry.toSaved();
                if (context.mounted) {
                  GoRouter.of(context).replace('/detail', extra: [saved]);
                }
              }
            },
          ),
          isnt: () => DionIconbutton(
            icon: Icon(
              entry is EntrySaved ? Icons.library_books : Icons.library_add,
              size: 30,
            ),
          ),
          shimmer: false,
        ),
        isEntryDetailed(
          context: context,
          entry: entry,
          isdetailed: (entry) => Foldabletext(
            maxLines: 7,
            entry.description.trim(),
            style: context.bodyMedium,
          ),
          isnt: () => Text(maxLines: 7, getText(70), style: context.bodyMedium),
        ).paddingOnly(top: 7),
        isEntryDetailed(
          context: context,
          entry: entry,
          isdetailed: (entry) => DionBadge(
            color: context.primaryColor.lighten(5),
            child: CustomUIWidget(ui: entry.ui, extension: entry.extension),
          ).paddingAll(5),
          isnt: () => nil,
          shimmer: false,
        ),
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

  @override
  Widget build(BuildContext context) {
    return ContextMenu(
      selectionActive: selected.isNotEmpty,
      active: widget.entry is EntrySaved,
      contextItems: [
        ContextMenuItem(
          label: 'Open in Browser',
          onTap: () async {
            await launchUrl(Uri.parse(widget.entry.url));
          },
        ),
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
          label: 'Mark as watched',
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
          label: 'Mark as unwatched',
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
          label: 'Delete Downloads',
          onTap: () async {
            final download = locate<DownloadService>();
            await download.deleteEpisodes(
              selection.map((index) => EpisodePath(widget.entry, index)),
            );
            selected.clear();
            setState(() {});
          },
        ),
        ContextMenuItem(
          label: 'Download to this episode',
          onTap: () async {
            final download = locate<DownloadService>();
            await download.download(
              Iterable.generate(
                selection.reduce((a, b) => max(a, b)) + 1,
                (index) => EpisodePath(widget.entry, index),
              ),
            );
            selected.clear();
            setState(() {});
          },
        ),
        ContextMenuItem(
          label: 'Mark to this episode',
          onTap: () async {
            for (int i = 0; i <= selection.reduce((a, b) => max(a, b)); i++) {
              final data = (widget.entry as EntrySaved).getEpisodeData(i);
              data.finished = true;
            }
            selected.clear();
            setState(() {});
            await (widget.entry as EntrySaved).save();
          },
        ),
      ],
      child: ListView.builder(
        key: PageStorageKey<String>(
          '${widget.entry.extension.id}->${widget.entry.id}',
        ),
        controller: controller,
        prototypeItem: EpisodeTile(
          episodepath: EpisodePath(widget.entry, 0),
          selection: false,
          isSelected: false,
          onSelect: () {},
        ),
        padding: EdgeInsets.zero,
        itemCount: widget.elist.length,
        itemBuilder: (BuildContext context, int index) => MouseRegion(
          onEnter: (e) {
            hovering = index;
          },
          child: EpisodeTile(
            disabled: widget.entry.extension.isenabled == false,
            episodepath: EpisodePath(widget.entry, index),
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
                      color: episodepath.entry.extension.isenabled
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
      trailing: SizedBox(
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
                      TaskStatus.running || null => CircularProgressIndicator(
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
              null => const CircularProgressIndicator(),
              Status.downloaded => DionIconbutton(
                icon: const Icon(Icons.check),
                onPressed: () async {
                  await locate<DownloadService>().deleteEpisode(episodepath);
                },
              ),
            };
          },
        ),
      ),
    );
  }
}

class CustomUIWidget extends StatelessWidget {
  final Extension extension;
  final CustomUI? ui;
  const CustomUIWidget({super.key, this.ui, required this.extension});

  @override
  Widget build(BuildContext context) {
    return switch (ui) {
      null => nil,
      final CustomUI_Text text => Text(text.text),
      final CustomUI_Image img => DionImage(
        imageUrl: img.image,
        httpHeaders: img.header,
      ),
      final CustomUI_Link link => Text(
        link.label ?? link.link,
        style: context.bodyMedium?.copyWith(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
      ).onTap(() => launchUrl(Uri.parse(link.link))),
      final CustomUI_TimeStamp timestamp => switch (timestamp.display) {
        TimestampType.relative => Text(
          DateTime.tryParse(timestamp.timestamp)?.formatrelative() ?? '',
        ),
        TimestampType.absolute => Text(
          DateTime.tryParse(timestamp.timestamp)?.toString() ?? '',
        ),
      },
      final CustomUI_EntryCard entryCard => EntryCard(
        entry: EntryImpl(entryCard.entry, extension),
      ),
      final CustomUI_Column column => SingleChildScrollView(
        child: Column(
          children: column.children
              .map((e) => CustomUIWidget(ui: e, extension: extension))
              .toList(),
        ),
      ),
      final CustomUI_Row row => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: row.children
              .map((e) => CustomUIWidget(ui: e, extension: extension))
              .toList(),
        ),
      ),
    };
  }
}
