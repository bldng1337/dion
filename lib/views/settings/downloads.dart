import 'dart:io';

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/service/downloads.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/safe_set_state.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/storage.dart';
import 'package:dionysos/widgets/buttons/clickable.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/container/container.dart';
import 'package:dionysos/widgets/context_menu.dart';
import 'package:dionysos/widgets/dialog.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:rdion_runtime/rdion_runtime.dart' show Link;

class ManageDownloads extends StatefulWidget {
  const ManageDownloads({super.key});

  @override
  State<ManageDownloads> createState() => _ManageDownloadsState();
}

class _ManageDownloadsState extends State<ManageDownloads> {
  List<DownloadedEntry>? _entries;
  Object? _error;
  StackTrace? _stack;
  bool _scanning = false;
  final Set<String> _selected = {};
  final Set<String> _expanded = {};
  String? _hovered;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    if (_scanning) return;
    _scanning = true;
    safeSetState();
    try {
      final entries = await locate<DownloadService>().listDownloads();
      _entries = entries;
      _error = null;
      _stack = null;
      final paths = <String>{
        for (final entry in entries) ...[
          entry.path.path,
          for (final ep in entry.episodes) ep.path.path,
        ],
      };
      _selected.removeWhere((path) => !paths.contains(path));
      _expanded.removeWhere((path) => !paths.contains(path));
    } catch (e, stack) {
      _error = e;
      _stack = stack;
    }
    _scanning = false;
    safeSetState();
  }

  void _toggleSelected(String path) {
    setState(() {
      if (!_selected.remove(path)) _selected.add(path);
    });
  }

  void _toggleExpanded(String path) {
    setState(() {
      if (!_expanded.remove(path)) _expanded.add(path);
    });
  }

  void _setHovered(String? path) {
    if (_hovered == path) return;
    setState(() {
      _hovered = path;
    });
  }

  ({int count, int size}) _statsFor(Set<String> paths) {
    var count = 0;
    var size = 0;
    for (final entry in _entries ?? const <DownloadedEntry>[]) {
      if (paths.contains(entry.path.path)) {
        count += entry.episodes.length;
        size += entry.size;
        continue;
      }
      for (final ep in entry.episodes) {
        if (paths.contains(ep.path.path)) {
          count++;
          size += ep.size;
        }
      }
    }
    return (count: count, size: size);
  }

  List<Directory> _dirsFor(Set<String> paths) {
    final dirs = <Directory>[];
    for (final entry in _entries ?? const <DownloadedEntry>[]) {
      if (paths.contains(entry.path.path)) {
        dirs.add(entry.path);
        continue;
      }
      for (final ep in entry.episodes) {
        if (paths.contains(ep.path.path)) dirs.add(ep.path);
      }
    }
    return dirs;
  }

  Future<void> _delete(Set<String> paths) async {
    final stats = _statsFor(paths);
    if (stats.count == 0) return;
    if (stats.count > 1 && !await _confirmDelete(stats.count, stats.size)) {
      return;
    }
    try {
      await locate<DownloadService>().deleteDownloadDirs(_dirsFor(paths));
    } catch (e, stack) {
      logger.e('Failed to delete downloads', error: e, stackTrace: stack);
    }
    await _scan();
  }

  Future<bool> _confirmDelete(int count, int size) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => DionAlertDialog(
        title: const Text('Delete Downloads'),
        content: Text(
          'Permanently delete $count downloaded episode'
          '${count == 1 ? '' : 's'} using ${formatBytes(size)}?',
        ),
        actions: [
          DionTextbutton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop(false);
            },
          ),
          DionTextbutton(
            child: const Text('Delete'),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
        ],
      ),
    );
    return result ?? false;
  }

  List<ContextMenuItem> _contextItems() {
    final hovered = _hovered;
    final targets = _selected.isNotEmpty
        ? _selected.toSet()
        : hovered != null
        ? {hovered}
        : <String>{};
    final stats = _statsFor(targets);
    return [
      if (stats.count > 0)
        ContextMenuItem(
          label: _selected.isNotEmpty
              ? 'Delete Selected (${stats.count})'
              : 'Delete Download',
          icon: Icons.delete_outline,
          section: 'Actions',
          isDestructive: true,
          onTap: () => _delete(targets),
        ),
      if (hovered != null)
        ContextMenuItem(
          label: _selected.contains(hovered)
              ? 'Deselect Item'
              : 'Select Item',
          icon: Icons.check_circle_outline,
          section: 'Selection',
          onTap: () async {
            _toggleSelected(hovered);
          },
        ),
      ContextMenuItem(
        label: 'Select All',
        icon: Icons.select_all,
        section: 'Selection',
        onTap: () async {
          final entries = _entries;
          if (entries == null) return;
          setState(() {
            _selected
              ..clear()
              ..addAll(entries.map((entry) => entry.path.path));
          });
        },
      ),
      if (_selected.isNotEmpty)
        ContextMenuItem(
          label: 'Clear Selection',
          icon: Icons.clear_all,
          section: 'Selection',
          onTap: () async {
            setState(() {
              _selected.clear();
            });
          },
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      title: const Text('Manage Downloads'),
      actions: [
        DionIconbutton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh, size: 18),
          onPressed: _scan,
        ),
      ],
      child: ContextMenu(
        selectionActive: _selected.isNotEmpty,
        selectionCount: _selected.isEmpty ? null : _statsFor(_selected).count,
        contextItems: _contextItems(),
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final error = _error;
    if (error != null) {
      return ErrorDisplay(
        e: error,
        s: _stack,
        actions: [ErrorAction(label: 'Retry', onTap: _scan)],
      );
    }
    final entries = _entries;
    if (entries == null) {
      return const Center(child: DionProgressBar());
    }
    if (entries.isEmpty) {
      return const Center(child: _DownloadsEmptyState());
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: DionSpacing.xxxl),
      itemCount: entries.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _DownloadsSummary(entries: entries, scanning: _scanning);
        }
        final entry = entries[index - 1];
        return _EntrySection(
          entry: entry,
          expanded: _expanded.contains(entry.path.path),
          selectedPaths: _selected,
          selectionActive: _selected.isNotEmpty,
          onToggleExpanded: _toggleExpanded,
          onToggleSelected: _toggleSelected,
          onHover: _setHovered,
          onDeleteEpisode: (path) => _delete({path}),
        );
      },
    );
  }
}

class _DownloadsSummary extends StatelessWidget {
  final List<DownloadedEntry> entries;
  final bool scanning;

  const _DownloadsSummary({required this.entries, required this.scanning});

  @override
  Widget build(BuildContext context) {
    final size = entries.fold<int>(0, (sum, entry) => sum + entry.size);
    final episodeCount = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.episodes.length,
    );
    final incomplete = entries.fold<int>(
      0,
      (sum, entry) =>
          sum + entry.episodes.where((ep) => !ep.finished).length,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DionSpacing.lg,
        DionSpacing.lg,
        DionSpacing.lg,
        DionSpacing.sm,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceMuted.withValues(alpha: 0.4),
          borderRadius: DionRadius.medium,
          border: Border.all(
            color: context.borderColor.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
        padding: const EdgeInsets.all(DionSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: DionColors.primary.withValues(alpha: 0.1),
                borderRadius: DionRadius.small,
              ),
              child: const Icon(
                Icons.download_outlined,
                size: 20,
                color: DionColors.primary,
              ),
            ),
            const SizedBox(width: DionSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatBytes(size),
                    style: DionTypography.titleMedium(context.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      '${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}',
                      '$episodeCount episode${episodeCount == 1 ? '' : 's'}',
                      if (incomplete > 0)
                        '$incomplete incomplete',
                    ].join('  ·  '),
                    style: DionTypography.bodySmall(context.textTertiary),
                  ),
                ],
              ),
            ),
            if (scanning)
              const SizedBox(
                width: 16,
                height: 16,
                child: DionProgressBar(size: 16),
              ),
          ],
        ),
      ),
    );
  }
}

class _EntrySection extends StatelessWidget {
  final DownloadedEntry entry;
  final bool expanded;
  final Set<String> selectedPaths;
  final bool selectionActive;
  final void Function(String path) onToggleExpanded;
  final void Function(String path) onToggleSelected;
  final void Function(String? path) onHover;
  final void Function(String path) onDeleteEpisode;

  const _EntrySection({
    required this.entry,
    required this.expanded,
    required this.selectedPaths,
    required this.selectionActive,
    required this.onToggleExpanded,
    required this.onToggleSelected,
    required this.onHover,
    required this.onDeleteEpisode,
  });

  String get _title => entry.entry?.title ?? 'Unknown Entry';

  String get _subtitle {
    final extName = entry.entry?.extension?.name;
    final incomplete = entry.episodes.where((ep) => !ep.finished).length;
    return [
      if (extName != null) extName
      else if (entry.entry == null) 'Not in library',
      '${entry.episodes.length} ${entry.episodes.length == 1 ? 'episode' : 'episodes'}',
      if (incomplete > 0) '$incomplete incomplete',
    ].join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    final selected = selectedPaths.contains(entry.path.path);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DionSpacing.md,
        DionSpacing.sm,
        DionSpacing.md,
        0,
      ),
      child: AnimatedSize(
        duration: DionDuration.normal,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTile(context, selected),
            if (expanded)
              for (final ep in entry.episodes)
                _buildEpisodeRow(context, ep, selectedPaths.contains(
                  ep.path.path,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, bool selected) {
    final cover = entry.entry?.poster ?? entry.entry?.cover;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Clickable(
        onTap: selectionActive
            ? () => onToggleSelected(entry.path.path)
            : () => onToggleExpanded(entry.path.path),
        onLongTap: () => onToggleSelected(entry.path.path),
        child: MouseRegion(
          onEnter: (_) => onHover(entry.path.path),
          child: DionContainer(
            color: selected
                ? context.theme.colorScheme.primary.lighten(70)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(DionSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCover(context, cover),
                  const SizedBox(width: DionSpacing.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: DionSpacing.xs,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              if (selectionActive) ...[
                                Icon(
                                  selected
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  size: 18,
                                  color: selected
                                      ? context.theme.colorScheme.primary
                                      : context.textTertiary,
                                ),
                                const SizedBox(width: DionSpacing.sm),
                              ],
                              Expanded(
                                child: Text(
                                  _title,
                                  style: DionTypography.titleSmall(
                                    context.textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _subtitle,
                            style: DionTypography.bodySmall(
                              context.textTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: DionSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatBytes(entry.size),
                        style: DionTypography.titleSmall(
                          context.theme.colorScheme.primary,
                        ),
                      ),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: DionDuration.normal,
                        child: Icon(
                          Icons.expand_more,
                          size: 18,
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCover(BuildContext context, Link? cover) {
    if (cover != null) {
      return ClipRRect(
        borderRadius: DionRadius.small,
        child: DionImage.fromLink(
          link: cover,
          width: 46,
          height: 64,
          boxFit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: 46,
      height: 64,
      decoration: BoxDecoration(
        color: context.surfaceMuted,
        borderRadius: DionRadius.small,
      ),
      child: Icon(
        Icons.help_outline,
        size: 20,
        color: context.textTertiary,
      ),
    );
  }

  Widget _buildEpisodeRow(
    BuildContext context,
    DownloadedEpisode ep,
    bool selected,
  ) {
    final number = ep.number;
    final name = _episodeName(ep);
    return Padding(
      padding: const EdgeInsets.only(
        left: DionSpacing.xl,
        bottom: 3,
      ),
      child: Clickable(
        onTap: selectionActive ? () => onToggleSelected(ep.path.path) : null,
        onLongTap: () => onToggleSelected(ep.path.path),
        child: MouseRegion(
          onEnter: (_) => onHover(ep.path.path),
          child: DionContainer(
            color: selected
                ? context.theme.colorScheme.primary.lighten(70)
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DionSpacing.sm,
                vertical: DionSpacing.xs + 2,
              ),
              child: Row(
                children: [
                  if (selectionActive)
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: selected
                          ? context.theme.colorScheme.primary
                          : context.textTertiary,
                    )
                  else if (number != null)
                    Text(
                      '${number + 1}',
                      style: DionTypography.labelSmall(context.textTertiary),
                    )
                  else
                    Icon(
                      Icons.subdirectory_arrow_right,
                      size: 14,
                      color: context.textTertiary,
                    ),
                  const SizedBox(width: DionSpacing.sm),
                  Expanded(
                    child: Text(
                      name,
                      style: DionTypography.bodySmall(context.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: DionSpacing.sm),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!ep.finished)
                        const Tooltip(
                          message: 'Incomplete download',
                          child: Icon(
                            Icons.warning_amber_outlined,
                            size: 15,
                            color: DionColors.warning,
                          ),
                        ),
                      const SizedBox(width: DionSpacing.sm),
                      Text(
                        formatBytes(ep.size),
                        style: DionTypography.bodySmall(context.textTertiary),
                      ),
                    ],
                  ),
                  if (!selectionActive)
                    DionIconbutton(
                      tooltip: 'Delete Download',
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => onDeleteEpisode(ep.path.path),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _episodeName(DownloadedEpisode ep) {
    final number = ep.number;
    final saved = entry.entry;
    if (saved != null &&
        number != null &&
        number >= 0 &&
        number < saved.episodes.length) {
      return saved.episodes[number].name;
    }
    return number != null ? 'Episode ${number + 1}' : ep.path.name;
  }
}

class _DownloadsEmptyState extends StatelessWidget {
  const _DownloadsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DionSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: DionColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.download_done_outlined,
              size: 32,
              color: DionColors.primary,
            ),
          ),
          const SizedBox(height: DionSpacing.lg),
          Text('No Downloads', style: context.titleMedium),
          const SizedBox(height: DionSpacing.xs),
          Text(
            'Downloaded episodes will appear here.',
            style: DionTypography.bodySmall(context.textSecondary),
          ),
        ],
      ),
    );
  }
}
