import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/extension.dart' hide TextStyle;
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/container/card.dart';
import 'package:dionysos/widgets/context_menu.dart';
import 'package:dionysos/widgets/dialog.dart';
import 'package:dionysos/widgets/dynamic_grid.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/popupmenu.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/searchbar.dart';
import 'package:flutter/material.dart'
    show Colors, Icons, ScaffoldMessenger, SnackBar, showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

Future<EntrySaved?> showMigrateEntryPage(
  BuildContext context,
  EntrySaved source,
) {
  return GoRouter.of(context).push<EntrySaved?>('/migrate', extra: [source]);
}

Future<EntrySaved> migrateEntry(EntrySaved source, Entry target) async {
  final detailed = await target.toDetailed();
  final newEpisodes = detailed.episodes.length;
  final db = locate<Database>();
  final migrated = EntrySaved(
    entry: detailed.toRust,
    boundExtensionId: detailed.boundExtensionId,
    extensionSettings: detailed.extensionSettings,
    categories: source.categories,
    savedSettings: source.savedSettings,
    // Episode data is per-episode (bookmark/finished/progress) keep as many as
    // fit the new entry. Extra data for episodes that no longer exist is dropped.
    episodedata: source.episodedata.take(newEpisodes).toList(),
    episode: source.episode.clamp(0, newEpisodes - 1 < 0 ? 0 : newEpisodes - 1),
    entryExtensions: source.entryExtensions,
    sourceExtensions: source.sourceExtensions,
  );
  await db.addEntry(migrated);
  await source.delete();
  return migrated;
}

class MigrateEntryPage extends StatefulWidget {
  const MigrateEntryPage({super.key});

  @override
  State<MigrateEntryPage> createState() => _MigrateEntryPageState();
}

class _MigrateEntryPageState extends State<MigrateEntryPage>
    with StateDisposeScopeMixin {
  late final TextEditingController controller;
  late final List<Extension> extensions;
  DataSourceController<Entry>? datacontroller;
  String? lastquery;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController()..disposedBy(scope);
    extensions = locate<ExtensionService>()
        .getExtensions(
          extfilter: (e) =>
              e.isenabled &&
              e.searchEnabled &&
              (e.getExtensionTypeOrNull<ExtensionType_EntryProvider>() !=
                      null ||
                  e.data.extensionType.isEmpty),
        )
        .toList(growable: false);
  }

  EntrySaved get sourceEntry {
    final extra = GoRouterState.of(context).extra! as List<Object?>;
    return extra[0]! as EntrySaved;
  }

  void runSearch(String query) {
    final trimmed = query.trim();
    if (trimmed == (lastquery ?? '')) return;
    lastquery = trimmed;
    datacontroller?.dispose();
    if (trimmed.isEmpty) {
      datacontroller = null;
      setState(() {});
      return;
    }
    datacontroller = DataSourceController<Entry>(
      extensions.map((e) => e.search(trimmed)).toList(),
    );
    setState(() {});
    datacontroller!.requestMore();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prefill = sourceEntry.title;
    if (lastquery == null) {
      controller.text = prefill;
      runSearch(prefill);
    }
  }

  Future<void> _onPick(Entry target) async {
    final source = sourceEntry;
    // Inspect the target before confirming so we can show its real metadata and
    // warn if it is already in the library.
    EntryDetailed? detailed;
    EntrySaved? existing;
    Object? loadError;
    if (mounted) setState(() => loading = true);
    try {
      final db = locate<Database>();
      existing = await db.isSaved(target);
      detailed = await target.toDetailed();
    } catch (e, stack) {
      logger.e('Failed to load migration target', error: e, stackTrace: stack);
      loadError = e;
    } finally {
      if (mounted) setState(() => loading = false);
    }
    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _MigrateConfirmDialog(
        source: source,
        target: target,
        targetDetailed: detailed,
        existing: existing,
        loadError: loadError,
      ),
    );
    if (result != true) return;
    if (!mounted) return;

    setState(() => loading = true);
    try {
      final migrated = await migrateEntry(
        source,
        existing ?? detailed ?? target,
      );
      if (!mounted) return;
      context.pop<EntrySaved?>(migrated);
    } catch (e, stack) {
      logger.e('Migration failed', error: e, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Migration failed: $e')));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = sourceEntry;
    return NavScaff(
      title: const Text('Migrate'),
      actions: [
        DionIconbutton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop<EntrySaved?>(),
        ),
      ],
      child: Stack(
        children: [
          Column(
            children: [
              _buildSourceHeader(context, source),
              DionSearchbar(
                controller: controller,
                hintText: 'Search',
                autofocus: true,
                style: const WidgetStatePropertyAll(TextStyle(fontSize: 20)),
                keyboardType: TextInputType.text,
                hintStyle: const WidgetStatePropertyAll(
                  TextStyle(color: Colors.grey),
                ),
                onSubmitted: runSearch,
              ).paddingAll(5),
              if (datacontroller == null)
                const Expanded(child: Center(child: Text('Type to search')))
              else
                DynamicGrid<Entry>(
                  showDataSources: false,
                  itemBuilder: (BuildContext context, item) =>
                      _MigrateResult(entry: item, onTap: () => _onPick(item)),
                  controller: datacontroller!,
                ).expanded(),
            ],
          ),
          if (loading)
            Container(
              color: Colors.black.withValues(alpha: 0.4),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 160,
                height: 160,
                child: DionDialog(child: Center(child: DionProgressBar())),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSourceHeader(BuildContext context, EntrySaved source) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: context.theme.colorScheme.onSurface.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          if (source.cover?.url != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: DionImage(
                imageUrl: source.cover!.url,
                httpHeaders: source.cover?.header,
                width: 40,
                height: 56,
                boxFit: BoxFit.cover,
              ),
            ).paddingOnly(right: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Migrating from',
                  style: context.labelSmall?.copyWith(
                    color: context.theme.colorScheme.onSurface.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                Text(
                  source.title,
                  style: context.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${source.boundExtensionId} • ${source.latestEpisode}/${source.totalEpisodes}',
                  style: context.labelSmall?.copyWith(
                    color: context.theme.colorScheme.onSurface.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MigrateResult extends StatelessWidget {
  final Entry entry;
  final Future<void> Function() onTap;
  const _MigrateResult({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ContextMenu(
      contextItems: [
        ContextMenuItem(
          label: 'Inspect',
          onTap: () => context.push('/detail', extra: [entry]),
        ),
        ContextMenuItem(label: 'Migrate here', onTap: onTap),
      ],
      child: EntryCard(entry: entry, onTapOverride: onTap),
    );
  }
}

class _MigrateConfirmDialog extends StatelessWidget {
  final EntrySaved source;
  final Entry target;
  final EntryDetailed? targetDetailed;
  final EntrySaved? existing;
  final Object? loadError;
  const _MigrateConfirmDialog({
    required this.source,
    required this.target,
    required this.targetDetailed,
    required this.existing,
    required this.loadError,
  });

  @override
  Widget build(BuildContext context) {
    final targetEpisodeCount = targetDetailed?.episodes.length ?? target.length;
    return DionDialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Migrate entry',
                style: context.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ).paddingOnly(bottom: 16),
              Row(
                children: [
                  Expanded(
                    child: _EntryPreview(
                      title: source.title,
                      cover: source.cover,
                      subtitle: source.boundExtensionId,
                      episodeInfo:
                          '${source.latestEpisode}/${source.totalEpisodes}',
                      badge: 'From',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_forward,
                      color: context.theme.colorScheme.onSurface.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _EntryPreview(
                      title: target.title,
                      cover: target.cover,
                      subtitle: target.boundExtensionId,
                      episodeInfo: targetEpisodeCount == null
                          ? null
                          : '$targetEpisodeCount episodes',
                      badge: 'To',
                    ),
                  ),
                ],
              ).paddingOnly(bottom: 16),
              if (loadError != null)
                _Notice(
                  context,
                  icon: Icons.error_outline,
                  color: context.theme.colorScheme.error,
                  text: 'Could not fully load the target: $loadError',
                ).paddingOnly(bottom: 12),
              if (existing != null)
                _Notice(
                  context,
                  icon: Icons.warning_amber_rounded,
                  color: context.theme.colorScheme.error,
                  text:
                      'This entry is already in your library. Its current progress will be replaced.',
                ).paddingOnly(bottom: 12),
              _Notice(
                context,
                icon: Icons.info_outline,
                color: context.theme.colorScheme.onSurface.withValues(
                  alpha: 0.6,
                ),
                text:
                    'Reading progress, bookmarks, categories and entry settings will be moved. Downloads are not migrated.',
              ).paddingOnly(bottom: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  DionTextbutton(
                    type: ButtonType.ghost,
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ).paddingOnly(right: 8),
                  DionTextbutton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Migrate'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryPreview extends StatelessWidget {
  final String title;
  final Link? cover;
  final String? subtitle;
  final String? episodeInfo;
  final String badge;
  const _EntryPreview({
    required this.title,
    required this.cover,
    required this.subtitle,
    required this.episodeInfo,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          badge.toUpperCase(),
          style: context.labelSmall?.copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            fontSize: 10,
            color: context.theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ).paddingOnly(bottom: 4),
        if (cover?.url != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: DionImage(
              imageUrl: cover!.url,
              httpHeaders: cover?.header,
              height: 100,
              boxFit: BoxFit.cover,
            ),
          ).paddingOnly(bottom: 6),
        Text(
          title,
          style: context.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: context.labelSmall?.copyWith(
              color: context.theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (episodeInfo != null)
          Text(
            episodeInfo!,
            style: context.labelSmall?.copyWith(
              color: context.theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  final BuildContext context;
  final IconData icon;
  final Color color;
  final String text;
  const _Notice(
    this.context, {
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color).paddingOnly(right: 8, top: 1),
        Expanded(
          child: Text(
            text,
            style: context.bodySmall?.copyWith(
              color: context.theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}
