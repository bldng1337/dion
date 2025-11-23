import 'dart:async';
import 'dart:math';

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/cancel_token.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/service/downloads.dart';

import 'package:dionysos/views/detail/entryinfo.dart';
import 'package:dionysos/views/detail/episodelist.dart';
import 'package:dionysos/views/detail/settings.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/context_menu.dart';
import 'package:dionysos/widgets/bounds.dart';
import 'package:dionysos/widgets/buttons/actionbutton.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Detail screen.
///
/// This file focuses on correct scrollbar behavior:
/// - Only a single explicit scrollbar is shown (platform-added scrollbars are disabled).
/// - The scrollbar thumb is offset from the top by the visible app bar height so it
///   doesn't draw over the app bar area.
/// - The offset is updated dynamically while scrolling (so when the cover collapses
///   the thumb position moves with it).
/// - The scrollbar thumb is shown only while hovering or actively scrolling and
///   hides after a short delay when idle.
class Detail extends StatefulWidget {
  const Detail({super.key});

  @override
  _DetailState createState() => _DetailState();
}

class _NoPlatformScrollbarBehavior extends ScrollBehavior {
  const _NoPlatformScrollbarBehavior();

  // Prevent the framework from inserting platform scrollbars automatically.
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _DetailState extends State<Detail> with StateDisposeScopeMixin {
  Entry? entry;
  late CancelToken tok;
  Object? error;
  StackTrace? errstack;
  List<int> selected = [];

  // Scroll controller used by the CustomScrollView and the RawScrollbar
  late final ScrollController _scrollController;

  // Notifier for top padding of the scrollbar thumb (the thumb's top inset).
  // This value follows the visible app bar height (statusbar+toolbar up to expandedHeight).
  final ValueNotifier<double> _scrollbarTopInset = ValueNotifier<double>(0.0);

  // Notifier for whether the scrollbar thumb should be visible (hovering or scrolling).
  final ValueNotifier<bool> _showScrollbar = ValueNotifier<bool>(false);

  // Timer used to auto-hide the scrollbar after scrolling stops and pointer is not over it.
  Timer? _hideTimer;

  // Tracks whether pointer is over the scrollbar area (to avoid hiding while hovered).
  bool _pointerOverScrollbar = false;

  // Cached values used by the scroll listener to compute visible appbar height fast.
  double _cachedExpandedHeight = 0.0;
  double _cachedToolbarTop = 0.0;

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
        selected.clear();
        setState(() {});
        await entry.save();
      },
    ),
    ContextMenuItem(
      label: 'Download',
      onTap: () async {
        final download = locate<DownloadService>();
        await download.download(
          selected.map((index) => EpisodePath(entry! as EntryDetailed, index)),
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
          selected.map((index) => EpisodePath(entry! as EntryDetailed, index)),
        );
        selected.clear();
        setState(() {});
      },
    ),
    if (selected.length == 1) ...[
      ContextMenuItem(
        label: 'Open in Browser',
        onTap: () async {
          await launchUrl(
            Uri.parse((entry! as EntryDetailed).episodes[selected.first].url),
          );
        },
      ),
    ],
    ContextMenuItem(
      label: 'Select to this episode',
      onTap: () async {
        final index = selected.reduce((a, b) => max(a, b)) + 1;
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

  void _onScroll() {
    // Update visible app bar height and set scrollbar inset accordingly.
    final offset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    final expanded = _cachedExpandedHeight;
    final toolbarTop = _cachedToolbarTop;

    if (expanded <= 0) {
      // No expandable area, keep inset at toolbarTop (status + toolbar).
      _scrollbarTopInset.value = toolbarTop;
      return;
    }

    final double visible = max(toolbarTop, expanded - offset);
    // small threshold to avoid noisy updates
    if ((_scrollbarTopInset.value - visible).abs() > 0.5) {
      _scrollbarTopInset.value = visible;
    }
  }

  void _showScrollbarTemporarily() {
    _hideTimer?.cancel();
    _showScrollbar.value = true;
    // Hide after a delay if pointer not over the scrollbar area.
    _hideTimer = Timer(const Duration(milliseconds: 900), () {
      if (!_pointerOverScrollbar) {
        _showScrollbar.value = false;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    tok = CancelToken()..disposedBy(scope);
    _scrollController = ScrollController()..disposedBy(scope);
    _scrollController.addListener(_onScroll);

    // default inset (status bar + toolbar) - will be overwritten in first build
    final window = WidgetsBinding.instance.window;
    _scrollbarTopInset.value = window.padding.top + kToolbarHeight;
    _showScrollbar.value = false;
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollbarTopInset.dispose();
    _showScrollbar.dispose();
    super.dispose();
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
          icon: const Icon(Icons.settings),
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

    // compute values used by the scroll listener for dynamic inset calculation
    final bool hasCover = entry?.cover?.url != null;
    final double expandedHeight = hasCover ? context.height * 0.25 : 0.0;
    final double toolbarTop =
        MediaQuery.of(context).padding.top + kToolbarHeight;

    _cachedExpandedHeight = expandedHeight;
    _cachedToolbarTop = toolbarTop;

    // ensure the inset matches current scroll position after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());

    return NavScaff(
      showNavbar: false,
      floatingActionButton:
          (entry is EntrySaved && (entry!.extension?.isenabled ?? false))
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
      child: ContextMenu(
        selectionActive: selected.isNotEmpty,
        active: entry is EntrySaved,
        contextItems: contextItems,
        child: ScrollConfiguration(
          // disable any automatic platform scrollbars for this subtree
          behavior: const _NoPlatformScrollbarBehavior(),
          child: ValueListenableBuilder<double>(
            valueListenable: _scrollbarTopInset,
            builder: (ctx, topInset, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: _showScrollbar,
                builder: (ctx2, show, _) {
                  // Wrap the RawScrollbar in MouseRegion to detect pointer hover
                  // over the scrollbar area so we don't hide while hovered.
                  return MouseRegion(
                    onEnter: (_) {
                      _pointerOverScrollbar = true;
                      _showScrollbar.value = true;
                      _hideTimer?.cancel();
                    },
                    onExit: (_) {
                      _pointerOverScrollbar = false;
                      // start hide timer
                      _hideTimer?.cancel();
                      _hideTimer = Timer(const Duration(milliseconds: 700), () {
                        if (!_pointerOverScrollbar) {
                          _showScrollbar.value = false;
                        }
                      });
                    },
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        // show scrollbar while actively scrolling and schedule hide
                        if (notification is ScrollStartNotification ||
                            notification is ScrollUpdateNotification) {
                          _showScrollbarTemporarily();
                        } else if (notification is ScrollEndNotification) {
                          // schedule hide once scrolling stops
                          _hideTimer?.cancel();
                          _hideTimer = Timer(
                            const Duration(milliseconds: 700),
                            () {
                              if (!_pointerOverScrollbar) {
                                _showScrollbar.value = false;
                              }
                            },
                          );
                        }
                        // do not consume the notification
                        return false;
                      },
                      child: RawScrollbar(
                        controller: _scrollController,
                        thumbVisibility: show,
                        radius: const Radius.circular(6),
                        thickness: 6,
                        // dynamic top padding follows the visible app bar height
                        padding: EdgeInsets.only(top: topInset),
                        child: CustomScrollView(
                          controller: _scrollController,
                          slivers: [
                            if (entry?.cover?.url != null)
                              SliverAppBar(
                                expandedHeight: expandedHeight,
                                pinned: true,
                                backgroundColor:
                                    context.theme.appBarTheme.backgroundColor,
                                surfaceTintColor: Colors.transparent,
                                actions: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: context
                                          .theme
                                          .appBarTheme
                                          .backgroundColor,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(children: actions),
                                  ).paddingOnly(right: 5),
                                ],
                                leading: Center(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: context
                                          .theme
                                          .appBarTheme
                                          .backgroundColor,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: DionIconbutton(
                                      icon: const Icon(Icons.arrow_back),
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                    ),
                                  ),
                                ),
                                flexibleSpace: FlexibleSpaceBar(
                                  collapseMode: CollapseMode.pin,
                                  background: DionImage(
                                    imageUrl: entry?.cover?.url,
                                    filterQuality: FilterQuality.high,
                                    boxFit: BoxFit.cover,
                                    httpHeaders: entry?.cover?.header,
                                    errorWidget: Container(
                                      color: context.theme.colorScheme.surface,
                                    ),
                                  ),
                                ),
                              )
                            else
                              SliverAppBar(pinned: true, actions: actions),
                            SliverToBoxAdapter(child: EntryInfo(entry: entry!)),
                            if (entry is EntryDetailed)
                              EpisodeListSliver(
                                entry: entry! as EntryDetailed,
                                selected: selected,
                                onSelect: (index) {
                                  if (selected.contains(index)) {
                                    selected.remove(index);
                                  } else {
                                    selected.add(index);
                                  }
                                  setState(() {});
                                },
                              ),
                            const SliverPadding(
                              padding: EdgeInsets.only(bottom: 100),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
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
  isnt ??= () => Container(color: Colors.white);
  if (entry is EntryDetailed) {
    return isdetailed(entry);
  }
  if (!shimmer) {
    return isnt();
  }
  return BoundsWidget(child: isnt()).applyShimmer(
    highlightColor: context.scaffoldBackgroundColor.lighten(20),
    baseColor: context.theme.scaffoldBackgroundColor,
  );
}
