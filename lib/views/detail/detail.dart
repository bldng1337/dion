import 'dart:async';
import 'dart:math';

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/downloads.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/utils/cancel_token.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/views/detail/entryinfo.dart';
import 'package:dionysos/views/detail/episodelist.dart';
import 'package:dionysos/views/detail/settings.dart';
import 'package:dionysos/widgets/buttons/actionbutton.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/context_menu.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
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
  List<int> selected = [];
  int? hovered;
  late final ScrollController _scrollController = ScrollController()
    ..disposedBy(scope);

  List<ContextMenuItem> get contextItems => [
    ContextMenuItem(
      label: 'Bookmark',
      onTap: () async {
        final entry = this.entry;
        if (entry is! EntrySaved) return;
        for (final int i in selected) {
          final data = entry.getEpisodeData(i);
          data.bookmark = true;
        }
        if (hovered != null) {
          final data = entry.getEpisodeData(hovered!);
          data.bookmark = true;
        }
        selected.clear();
        setState(() {});
        await entry.save();
      },
    ),
    ContextMenuItem(
      label: 'Remove Bookmark',
      onTap: () async {
        final entry = this.entry;
        if (entry is! EntrySaved) return;
        for (final int i in selected) {
          final data = entry.getEpisodeData(i);
          data.bookmark = false;
        }
        if (hovered != null) {
          final data = entry.getEpisodeData(hovered!);
          data.bookmark = false;
        }
        selected.clear();
        setState(() {});
        await entry.save();
      },
    ),
    ContextMenuItem(
      label: 'Mark as finished',
      onTap: () async {
        final entry = this.entry;
        if (entry is! EntrySaved) return;
        for (final int i in selected) {
          final data = entry.getEpisodeData(i);
          data.finished = true;
        }
        if (hovered != null) {
          final data = entry.getEpisodeData(hovered!);
          data.finished = true;
        }
        selected.clear();
        setState(() {});
        await entry.save();
      },
    ),
    ContextMenuItem(
      label: 'Mark as unfinished',
      onTap: () async {
        final entry = this.entry;
        if (entry is! EntrySaved) return;
        for (final int i in selected) {
          final data = entry.getEpisodeData(i);
          data.finished = false;
          data.progress = null;
        }
        if (hovered != null) {
          final data = entry.getEpisodeData(hovered!);
          data.finished = false;
          data.progress = null;
        }
        selected.clear();
        setState(() {});
        await entry.save();
      },
    ),
    ContextMenuItem(
      label: 'Download',
      onTap: () async {
        final download = locate<DownloadService>();
        await download.download([
          ...selected.map(
            (index) => EpisodePath(entry! as EntryDetailed, index),
          ),
          if (hovered != null && !selected.contains(hovered))
            EpisodePath(entry! as EntryDetailed, hovered!),
        ]);
        selected.clear();
        setState(() {});
      },
    ),
    ContextMenuItem(
      label: 'Delete Download',
      onTap: () async {
        final download = locate<DownloadService>();
        await download.deleteEpisodes([
          ...selected.map(
            (index) => EpisodePath(entry! as EntryDetailed, index),
          ),
          if (hovered != null && !selected.contains(hovered))
            EpisodePath(entry! as EntryDetailed, hovered!),
        ]);
        selected.clear();
        setState(() {});
      },
    ),
    if (selected.length == 1 || (selected.isEmpty && hovered != null))
      ContextMenuItem(
        label: 'Open in Browser',
        onTap: () async {
          if (selected.isEmpty) {
            if (hovered == null) return;
            await launchUrl(
              Uri.parse((entry! as EntryDetailed).episodes[hovered!].url),
            );
            return;
          }
          await launchUrl(
            Uri.parse((entry! as EntryDetailed).episodes[selected.first].url),
          );
        },
      ),
    ContextMenuItem(
      label: 'Select to this episode',
      onTap: () async {
        final index =
            max(selected.fold(-1, (a, b) => max(a, b)), hovered ?? -1) + 1;
        if (index < 0) return;
        selected.clear();
        selected.addAll(Iterable.generate(index, (index) => index));
        setState(() {});
      },
    ),
    if (entry is EntrySaved)
      ContextMenuItem(
        label: 'Select finished episodes',
        onTap: () async {
          final entry = this.entry;
          if (entry is! EntrySaved) return;
          selected.clear();
          selected.addAll(
            entry.episodes.indexed
                .where((e) => entry.getEpisodeData(e.$1).finished)
                .map((e) => e.$1)
                .toList(),
          );
          setState(() {});
        },
      ),
    if (entry is EntrySaved)
      ContextMenuItem(
        label: 'Select unfinished episodes',
        onTap: () async {
          final entry = this.entry;
          if (entry is! EntrySaved) return;
          selected.clear();
          selected.addAll(
            entry.episodes.indexed
                .where((e) => !entry.getEpisodeData(e.$1).finished)
                .map((e) => e.$1)
                .toList(),
          );
          setState(() {});
        },
      ),
    ContextMenuItem(
      label: 'Select All',
      onTap: () async {
        final entry = this.entry;
        if (entry is! EntryDetailed) return;
        selected.clear();
        selected.addAll(entry.episodes.indexed.map((e) => e.$1).toList());
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

  Future<void> loadEntry() async {
    if (entry is EntrySaved) {
      return;
    }
    try {
      final saved = await locate<Database>().isSaved(entry!);
      if (saved != null) {
        entry = saved;
        if (mounted) {
          setState(() {});
        }
        return;
      }
    } catch (e, stack) {
      logger.e('Error checking if entry is saved', error: e, stackTrace: stack);
      error = e;
      if (mounted) {
        setState(() {});
      }
      return;
    }
    if (entry is EntryDetailed) {
      return;
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
    if (entry.runtimeType == newentry.runtimeType && newentry.id == entry?.id) {
      return;
    }
    if (!mounted) return;
    setState(() {});
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
        child: ErrorDisplay(
          e: error,
          s: errstack,
          actions: [ErrorAction(label: 'Reload', onTap: () => loadEntry())],
        ),
      );
    }
    if (entry == null) {
      return const NavScaff(child: Center(child: DionProgressBar()));
    }
    final ext = entry!.extension;
    if (entry is EntryDetailed && ext != null) {
      return ListenableBuilder(
        listenable: ext,
        builder: (context, child) => buildDetailScreen(context),
      );
    }
    return buildDetailScreen(context);
  }

  Widget buildDetailScreen(BuildContext context) {
    final actions = [
      if (entry is EntrySaved && (entry!.extension?.isenabled ?? false))
        DionIconbutton(
          onPressed: () {
            showSettingPopup(context, entry! as EntrySaved);
          },
          icon: const Icon(Icons.settings_outlined, size: 18),
        ),
      if (entry is EntrySaved && (entry!.extension?.isenabled ?? false))
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
          icon: const Icon(Icons.refresh, size: 18),
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
          icon: const Icon(Icons.open_in_browser, size: 18),
        ),
    ];
    return NavScaff(
      showNavbar: false,
      floatingActionButton:
          (entry is EntrySaved && (entry!.extension?.isenabled ?? false))
          ? ActionButton(
              onPressed: () async {
                EpisodePath(
                  entry! as EntryDetailed,
                  min(
                    (entry! as EntrySaved).latestEpisode,
                    (entry! as EntrySaved).episodes.length - 1,
                  ),
                ).go(context);
              },
              child: const Icon(Icons.play_arrow, size: 26),
            )
          : null,
      child: ContextMenu(
        selectionActive: selected.isNotEmpty,
        active: entry is EntrySaved,
        contextItems: contextItems,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            if (entry?.cover?.url != null ||
                (entry is EntryDetailed &&
                    (entry! as EntryDetailed).poster?.url != null))
              _buildHeader(context, actions)
            else
              SliverAppBar(
                pinned: true,
                surfaceTintColor: Colors.transparent,
                actions: [_buildActionsContainer(context, actions)],
                leading: _buildLeadingButton(context),
              ),
            SliverToBoxAdapter(child: EntryInfo(entry: entry!)),
            if (entry is EntryDetailed)
              EpisodeListSliver(
                entry: entry! as EntryDetailed,
                selected: selected,
                onEnter: (index) {
                  if (hovered == index) return;
                  setState(() {
                    hovered = index;
                  });
                },
                onSelect: (index) {
                  if (selected.contains(index)) {
                    selected.remove(index);
                  } else {
                    selected.add(index);
                  }
                  setState(() {});
                },
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsContainer(BuildContext context, List<Widget> actions) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: context.theme.appBarTheme.backgroundColor,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(children: actions),
    ).paddingOnly(right: 8);
  }

  Widget _buildLeadingButton(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(left: 12),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: context.theme.appBarTheme.backgroundColor,
          borderRadius: BorderRadius.circular(3),
        ),
        child: DionIconbutton(
          icon: const Icon(Icons.arrow_back, size: 18),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, List<Widget> actions) {
    return SliverAppBar(
      expandedHeight: context.width > 600 ? 420 : 210,
      pinned: true,
      surfaceTintColor: Colors.transparent,
      actions: [_buildActionsContainer(context, actions)],
      leading: _buildLeadingButton(context),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Stack(
          fit: StackFit.expand,
          children: [
            DionImage.fromLink(
              link: (entry is EntryDetailed)
                  ? (entry! as EntryDetailed).poster ?? entry?.cover
                  : entry?.cover,
              filterQuality: FilterQuality.high,
              boxFit: BoxFit.cover,
              alignment: const Alignment(0, -0.3),
              errorWidget: Container(color: context.theme.colorScheme.surface),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.85, 0.98, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      context.theme.scaffoldBackgroundColor.withValues(
                        alpha: 0.8,
                      ),
                      context.theme.scaffoldBackgroundColor,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
