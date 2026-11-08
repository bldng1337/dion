import 'dart:async';
import 'dart:math';

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/downloads.dart';
import 'package:dionysos/service/extension.dart'
    hide
        Alignment,
        ContainerType,
        CrossAxisAlignment,
        EdgeInsets,
        MainAxisAlignment,
        MainAxisSize,
        StackFit,
        TextStyle,
        WrapAlignment;
import 'package:dionysos/utils/cancel_token.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/media_type.dart';
import 'package:dionysos/utils/safe_set_state.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/views/detail/entryinfo.dart';
import 'package:dionysos/views/detail/episodelist.dart';
import 'package:dionysos/views/detail/saved_quotes.dart';
import 'package:dionysos/views/detail/settings.dart';
import 'package:dionysos/views/dialog/migrate.dart';
import 'package:dionysos/widgets/buttons/actionbutton.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/context_menu.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Entry? _lastSeed;
  late CancelToken tok;
  Object? error;
  StackTrace? errstack;

  Object? refreshError;
  StackTrace? refreshStack;
  List<int> selected = [];
  int? hovered;
  late final ScrollController _scrollController = ScrollController()
    ..disposedBy(scope);

  bool _isSelectable(int index) =>
      (entry! as EntryDetailed).episodes[index].announced != true;

  String get _unitName => entry!.mediaType.episodeName.toLowerCase();
  String get _unitNames => entry!.mediaType.getEpisodeNames(2).toLowerCase();

  List<ContextMenuItem> get contextItems {
    final target = hovered;
    final targets = {...selected, ?target};
    return [
      ContextMenuItem(
        label: 'Bookmark',
        icon: Icons.bookmark_border,
        section: 'Actions',
        onTap: () =>
            _updateEpisodeData(targets, (data) => data.bookmark = true),
      ),
      ContextMenuItem(
        label: 'Remove Bookmark',
        icon: Icons.bookmark_remove,
        onTap: () =>
            _updateEpisodeData(targets, (data) => data.bookmark = false),
      ),
      ContextMenuItem(
        label: 'Mark as finished',
        icon: Icons.task_alt,
        onTap: () =>
            _updateEpisodeData(targets, (data) => data.finished = true),
      ),
      ContextMenuItem(
        label: 'Mark as unfinished',
        icon: Icons.circle_outlined,
        onTap: () => _updateEpisodeData(targets, (data) {
          data.finished = false;
          data.progress = null;
        }),
      ),
      ContextMenuItem(
        label: 'Download',
        icon: Icons.download_outlined,
        onTap: () async {
          final download = locate<DownloadService>();
          await download.download([
            for (final index in targets)
              if (_isSelectable(index))
                EpisodePath(entry! as EntryDetailed, index),
          ]);
          selected.clear();
          safeSetState();
        },
      ),
      ContextMenuItem(
        label: 'Delete Download',
        icon: Icons.delete_outline,
        isDestructive: true,
        onTap: () async {
          final download = locate<DownloadService>();
          await download.deleteEpisodes([
            for (final index in targets)
              EpisodePath(entry! as EntryDetailed, index),
          ]);
          selected.clear();
          safeSetState();
        },
      ),
      if (entry is EntrySaved && targets.length == 1)
        ContextMenuItem(
          label: 'Note',
          icon: Icons.sticky_note_2_outlined,
          onTap: () async {
            final index = targets.single;
            selected.clear();
            setState(() {});
            if (context.mounted) {
              await context.push('/note', extra: [entry!, index]);
            }
          },
        ),
      if (targets.length == 1)
        ContextMenuItem(
          label: 'Open in Browser',
          icon: Icons.open_in_browser,
          onTap: () async {
            await launchUrl(
              Uri.parse((entry! as EntryDetailed).episodes[targets.single].url),
            );
          },
        ),
      ContextMenuItem(
        label: 'Select to this $_unitName',
        icon: Icons.playlist_add_check,
        section: 'Selection',
        onTap: () async {
          final end = max(selected.fold(-1, max), target ?? -1) + 1;
          _select(Iterable.generate(end, (index) => index));
        },
      ),
      if (entry is EntrySaved)
        ContextMenuItem(
          label: 'Select finished $_unitNames',
          icon: Icons.done_all,
          onTap: () async {
            final entry = this.entry! as EntrySaved;
            _select(
              entry.episodes.indexed
                  .where((e) => entry.getEpisodeData(e.$1).finished)
                  .map((e) => e.$1),
            );
          },
        ),
      if (entry is EntrySaved)
        ContextMenuItem(
          label: 'Select unfinished $_unitNames',
          icon: Icons.remove_done,
          onTap: () async {
            final entry = this.entry! as EntrySaved;
            _select(
              entry.episodes.indexed
                  .where((e) => !entry.getEpisodeData(e.$1).finished)
                  .map((e) => e.$1),
            );
          },
        ),
      ContextMenuItem(
        label: 'Select All',
        icon: Icons.select_all,
        onTap: () async {
          final entry = this.entry;
          if (entry is! EntryDetailed) return;
          _select(entry.episodes.indexed.map((e) => e.$1));
        },
      ),
      if (selected.isNotEmpty)
        ContextMenuItem(
          label: 'Clear Selection',
          icon: Icons.clear_all,
          onTap: () async {
            selected.clear();
            setState(() {});
          },
        ),
    ];
  }

  Future<void> _updateEpisodeData(
    Set<int> targets,
    void Function(EpisodeData data) update,
  ) async {
    final entry = this.entry;
    if (entry is! EntrySaved) return;
    targets.map(entry.getEpisodeData).forEach(update);
    selected.clear();
    setState(() {});
    await entry.save();
  }

  void _select(Iterable<int> indices) {
    selected
      ..clear()
      ..addAll(indices.where(_isSelectable));
    setState(() {});
  }

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
      errstack = stack;
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
      errstack = stack;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> refreshEntry({bool full = false}) async {
    try {
      if (tok.isDisposed) {
        tok = CancelToken()..disposedBy(scope);
      }
      final e = await (entry! as EntrySaved).refresh(token: tok, full: full);
      entry = e;
      refreshError = null;
      refreshStack = null;
      if (mounted) {
        setState(() {});
      }
    } catch (e, stack) {
      refreshError = e;
      refreshStack = stack;
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
    if (identical(newentry, _lastSeed)) {
      return;
    }
    if (!mounted) return;
    setState(() {});
    entry = newentry;
    _lastSeed = newentry;
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
          actions: [
            ErrorAction(
              label: 'Reload',
              onTap: () {
                setState(() {
                  error = null;
                  errstack = null;
                });
                loadEntry();
              },
            ),
          ],
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
      if (entry is EntrySaved)
        DionIconbutton(
          tooltip: 'Note',
          onPressed: () {
            context.push('/note', extra: [entry!]);
          },
          icon: const Icon(Icons.sticky_note_2_outlined, size: 18),
        ),
      if (entry is EntrySaved)
        ListenableBuilder(
          listenable: locate<Database>().getListenable(DBEvent.entryUpdated),
          builder: (context, _) {
            if (!entryHasSavedContent(entry! as EntrySaved)) {
              return const SizedBox.shrink();
            }
            return DionIconbutton(
              tooltip: 'Saved Quotes',
              onPressed: () {
                context.push('/quotes', extra: [entry!]);
              },
              icon: const Icon(Icons.format_quote, size: 18),
            );
          },
        ),
      if (entry is EntrySaved && (entry!.extension?.isenabled ?? false))
        DionIconbutton(
          tooltip: 'Entry Settings',
          onPressed: () {
            showSettingPopup(context, entry! as EntrySaved);
          },
          icon: const Icon(Icons.settings_outlined, size: 18),
        ),
      if (entry is EntrySaved && (entry!.extension?.isenabled ?? false))
        DionIconbutton(
          tooltip: 'Refresh (hold Shift or long press for full refresh)',
          onPressed: () =>
              refreshEntry(full: HardwareKeyboard.instance.isShiftPressed),
          onLongPress: () => refreshEntry(full: true),
          icon: const Icon(Icons.refresh, size: 18),
        ),
      if (entry is EntrySaved)
        DionIconbutton(
          tooltip: 'Migrate',
          onPressed: () async {
            final navigator = GoRouter.of(context);
            final migrated = await showMigrateEntryPage(
              context,
              entry! as EntrySaved,
            );
            if (migrated != null && context.mounted) {
              navigator.replace('/detail', extra: [migrated]);
              setState(() {
                entry = migrated;
              });
            }
          },
          icon: const Icon(Icons.swap_horiz, size: 18),
        ),
      if (entry is EntryDetailed)
        DionIconbutton(
          tooltip: 'Open in Browser',
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
              tooltip: 'Continue',
              onPressed: () async {
                final saved = entry! as EntrySaved;
                // Never continue into an episode the source has announced
                // but not released yet.
                final lastPlayable =
                    saved.latestEpisode < saved.releasedEpisodes
                    ? saved.latestEpisode
                    : saved.releasedEpisodes - 1;
                if (lastPlayable < 0) return;
                EpisodePath(entry! as EntryDetailed, lastPlayable).go(context);
              },
              child: const Icon(Icons.play_arrow, size: 26),
            )
          : null,
      child: ContextMenu(
        selectionActive: selected.isNotEmpty,
        selectionCount: selected.length,
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
            if (refreshError != null)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 76,
                  child: ErrorDisplay(
                    e: refreshError,
                    s: refreshStack,
                    message: 'Refresh failed',
                  ),
                ).paddingAll(DionSpacing.sm),
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
                onExit: (index) {
                  if (hovered != index) return;
                  setState(() {
                    hovered = null;
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
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: DionSpacing.xs,
      ),
      margin: const EdgeInsets.only(right: DionSpacing.md),
      decoration: BoxDecoration(
        color: context.theme.appBarTheme.backgroundColor,
        borderRadius: BorderRadius.circular(DionRadius.sm),
      ),
      child: Row(children: actions),
    ).paddingOnly(right: DionSpacing.sm);
  }

  Widget _buildLeadingButton(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(left: DionSpacing.md),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: context.theme.appBarTheme.backgroundColor,
          borderRadius: BorderRadius.circular(DionRadius.sm),
        ),
        child: DionIconbutton(
          tooltip: 'Back',
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
      expandedHeight: context.isCompactWindow ? 210 : 420,
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
