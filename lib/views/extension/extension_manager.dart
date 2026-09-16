import 'dart:io';

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/routes.dart';
import 'package:dionysos/service/extension.dart' as src;
import 'package:dionysos/service/extension_updates.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/toast.dart';
import 'package:dionysos/utils/version.dart';
import 'package:dionysos/views/extension/extension_meta.dart';
import 'package:dionysos/views/extension/permission_dialog.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/container/listtile.dart';
import 'package:dionysos/widgets/dynamic_grid.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/tabbar.dart';
import 'package:dionysos/widgets/text_scroll.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart'
    show
        AlertDialog,
        Colors,
        ConstrainedBox,
        FilterChip,
        Icons,
        InputDecoration,
        TextButton,
        TextField,
        Tooltip,
        showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:inline_result/inline_result.dart';

class ExtensionManager extends StatefulWidget {
  const ExtensionManager({super.key});

  @override
  _ExtensionManagerState createState() => _ExtensionManagerState();
}

class _ExtensionManagerState extends State<ExtensionManager> {
  bool loading = false;
  Object? error;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return NavScaff(
        title: const DionTextScroll('Manage Extensions'),
        destination: homedestinations,
        child: Center(
          child: ErrorDisplay(
            e: error,
            actions: [
              ErrorAction(
                label: 'Reload',
                onTap: () {
                  setState(() {
                    error = null;
                  });
                },
              ),
            ],
          ),
        ),
      );
    }
    if (loading) {
      return NavScaff(
        title: const DionTextScroll('Manage Extensions'),
        destination: homedestinations,
        child: const Center(child: DionProgressBar()),
      );
    }
    final sourceExt = locate<src.ExtensionService>();

    return NavScaff(
      title: const DionTextScroll('Manage Extensions'),
      actions: [
        ValueListenableBuilder<bool>(
          valueListenable: locate<ExtensionUpdateService>().checking,
          builder: (context, checking, _) => DionIconbutton(
            tooltip: 'Check for Updates',
            onPressed: checking
                ? null
                : () => locate<ExtensionUpdateService>().checkNow(),
            icon: checking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: DionProgressBar(),
                  )
                : const Icon(Icons.update),
          ),
        ),
        DionIconbutton(
          tooltip: 'Refresh Installed',
          onPressed: () async {
            setState(() {
              loading = true;
            });
            try {
              await sourceExt.reload();
            } catch (e, stack) {
              logger.e(e, stackTrace: stack);
              error = e;
            }
            if (!mounted) {
              return;
            }
            setState(() {
              loading = false;
            });
          },
          icon: const Icon(Icons.refresh),
        ),
        DionIconbutton(
          tooltip: 'Add Repository',
          onPressed: () async {
            await showAddRepositoryDialog(context);
            if (mounted) {
              setState(() {});
            }
          },
          icon: const Icon(Icons.add_link),
        ),
        DionIconbutton(
          tooltip: 'Install from File',
          onPressed: () async {
            const XTypeGroup typeGroup = XTypeGroup(
              label: 'Extensions',
              extensions: <String>['js', 'apk'],
            );
            final List<XFile> files;
            try {
              files = await openFiles(
                acceptedTypeGroups: <XTypeGroup>[typeGroup],
              );
            } catch (e, stack) {
              logger.e(
                'Failed to open extension file picker',
                error: e,
                stackTrace: stack,
              );
              return;
            }
            if (files.isEmpty) {
              return;
            }
            if (mounted) {
              setState(() {
                loading = true;
              });
            }
            final updateService = locate<ExtensionUpdateService>();
            var installedCount = 0;
            var updatedCount = 0;
            final failedFiles = <String>[];
            for (final xfile in files) {
              final known = sourceExt.getExtensions().toSet();
              try {
                await sourceExt.install(File(xfile.path).fileURL);
                final added = sourceExt
                    .getExtensions()
                    .where((e) => !known.contains(e))
                    .toList();
                // Installing over an existing extension swaps the instance
                // but keeps its id, so an id that was already present means
                // the file updated that extension instead of adding one.
                final newExt = added.isEmpty ? null : added.first;
                final isUpdate =
                    newExt != null &&
                    known.any((e) => e.data.id == newExt.data.id);
                if (isUpdate) {
                  updatedCount++;
                } else {
                  installedCount++;
                }
                final pending = newExt == null
                    ? null
                    : updateService.updates.value[newExt.data.id];
                if (newExt != null &&
                    pending != null &&
                    parseVersion(pending.version) <= newExt.version) {
                  updateService.markUpdated(newExt.data.id);
                }
              } catch (e, stack) {
                logger.e(
                  'Failed to install extension from ${xfile.path}',
                  error: e,
                  stackTrace: stack,
                );
                failedFiles.add(xfile.name);
              }
            }
            if (mounted) {
              setState(() {
                loading = false;
              });
            }
            _showFileInstallToast(
              fileNames: files.map((f) => f.name).toList(),
              installedCount: installedCount,
              updatedCount: updatedCount,
              failedFiles: failedFiles,
            );
          },
          icon: const Icon(Icons.install_desktop),
        ),
      ],
      destination: homedestinations,
      child: DionTabBar(
        tabs: [
          DionTab(
            child: const ExtensionList(),
            tab: const Text('Installed').paddingAll(6),
          ),
          DionTab(
            child: const ExtensionCatalog(),
            tab: const Text('Available').paddingAll(6),
          ),
        ],
      ),
    );
  }
}

class ExtensionList extends StatefulWidget {
  const ExtensionList({super.key});

  @override
  State<ExtensionList> createState() => _ExtensionListState();
}

class _ExtensionListState extends State<ExtensionList>
    with StateDisposeScopeMixin {
  late final TextEditingController _searchController = TextEditingController()
    ..disposedBy(scope);

  ExtensionFilters _filters = const ExtensionFilters();

  void _setFilters(ExtensionFilters next) {
    setState(() {
      _filters = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sourceExt = locate<src.ExtensionService>();
    final updateService = locate<ExtensionUpdateService>();
    return ListenableBuilder(
      listenable: sourceExt,
      builder: (context, child) {
        if (sourceExt.loading) {
          return const Center(child: DionProgressBar());
        }
        final all = sourceExt.getExtensions().toList(growable: false);
        return ValueListenableBuilder<Map<String, src.RemoteExtension>>(
          valueListenable: updateService.updates,
          builder: (context, updateMap, _) {
            final exts = all
                .where(_filters.matchesInstalled)
                .toList(growable: false);
            return Column(
              children: [
                ExtensionFilterBar(
                  searchController: _searchController,
                  searchHint: 'Search installed extensions',
                  filters: _filters,
                  languageOptions: {for (final e in all) ...e.data.lang},
                  onChanged: _setFilters,
                ),
                Expanded(
                  child: exts.isEmpty
                      ? Center(
                          child: Text(
                            all.isEmpty
                                ? 'No extensions installed'
                                : 'No extensions match the current filters',
                          ),
                        )
                      : ListView.builder(
                          itemCount: exts.length,
                          itemBuilder: (context, i) {
                            final ext = exts[i];
                            final update = updateMap[ext.id];
                            return ListenableBuilder(
                              listenable: ext,
                              builder: (context, child) => DionListTile(
                                leading: SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Stack(
                                    children: [
                                      Center(
                                        child: DionImage(
                                          imageUrl: ext.data.icon,
                                          width: 30,
                                          height: 30,
                                          errorWidget: const Icon(
                                            Icons.image,
                                            size: 30,
                                          ),
                                        ),
                                      ),
                                      if (ext.loading) const DionProgressBar(),
                                    ],
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        ext.name,
                                        style: context.titleMedium?.copyWith(
                                          color: ext.isenabled
                                              ? context.theme.colorScheme.primary
                                              : Colors.grey,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: DionSpacing.sm),
                                    Text(
                                      'v${ext.data.version}',
                                      style: context.bodySmall?.copyWith(
                                        color: context
                                            .theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () => ext.toggle(),
                                onLongTap: () =>
                                    context.push('/extension/${ext.data.id}'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ExtensionMetaChips(
                                      kinds: ext.extensionKinds,
                                      mediaTypes: ext.data.mediaType,
                                      nsfw: ext.data.nsfw,
                                      languages: ext.data.lang,
                                      iconOnlyKinds: true,
                                      maxLanguages: 3,
                                    ),
                                    if (update != null)
                                      Text(
                                        'Update available: v${update.version}',
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (update != null)
                                      DionIconbutton(
                                        tooltip: 'Update',
                                        icon: const Icon(
                                          Icons.system_update_alt,
                                          color: Colors.green,
                                        ),
                                        onPressed: () async {
                                          await update.install();
                                          updateService.markUpdated(ext.id);
                                        },
                                      ),
                                    DionIconbutton(
                                      tooltip: 'Uninstall',
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => sourceExt.uninstall(ext),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Per-repository resolution so the catalog can show, for every configured
/// repo, whether it is still loading, loaded, or failed (retryable by
/// tapping its chip).
sealed class _RepoResolution {
  final String url;
  const _RepoResolution(this.url);
}

class _RepoLoading extends _RepoResolution {
  const _RepoLoading(super.url);
}

class _RepoReady extends _RepoResolution {
  final src.RemoteExtensionRepo repo;
  const _RepoReady(super.url, this.repo);

  String get label => repo.data.name.isNotEmpty ? repo.data.name : url;
}

class _RepoFailed extends _RepoResolution {
  final Object error;
  const _RepoFailed(super.url, this.error);
}

class ExtensionCatalog extends StatefulWidget {
  const ExtensionCatalog({super.key});

  @override
  State<ExtensionCatalog> createState() => _ExtensionCatalogState();
}

class _ExtensionCatalogState extends State<ExtensionCatalog>
    with StateDisposeScopeMixin {
  Map<String, _RepoResolution> _repos = {};

  int _resolveGeneration = 0;

  String? _selectedRepoUrl;

  bool _updatesOnly = false;

  ExtensionFilters _filters = const ExtensionFilters();

  late final TextEditingController _searchController = TextEditingController()
    ..disposedBy(scope);

  DataSourceController<src.RemoteExtension>? _controller;

  bool get _hasPending => _repos.values.any((r) => r is _RepoLoading);

  bool get _hasReady => _repos.values.any((r) => r is _RepoReady);

  bool get _hasFailed => _repos.values.any((r) => r is _RepoFailed);

  @override
  void initState() {
    super.initState();
    settings.extension.repositories.addListener(_onRepositoriesChanged);
    _resolveAll();
  }

  @override
  void dispose() {
    settings.extension.repositories.removeListener(_onRepositoriesChanged);
    _controller?.dispose();
    super.dispose();
  }

  void _onRepositoriesChanged() {
    _resolveAll();
  }

  Future<void> _resolveAll() async {
    final urls = settings.extension.repositories.value;
    final generation = ++_resolveGeneration;
    setState(() {
      _repos = {for (final url in urls) url: _RepoLoading(url)};
      if (_selectedRepoUrl != null && !urls.contains(_selectedRepoUrl)) {
        _selectedRepoUrl = null;
      }
      _rebuildController();
    });
    for (final url in urls) {
      // Unawaited on purpose: each repo resolves independently and updates
      // its own chip; the generation guard drops stale results.
      _resolveOne(url, generation);
    }
  }

  Future<void> _resolveOne(String url, int generation) async {
    final sourceExt = locate<src.ExtensionService>();
    setState(() {
      _repos[url] = _RepoLoading(url);
    });
    try {
      final repo = await sourceExt.getRepo(url);
      if (!mounted || generation != _resolveGeneration) {
        return;
      }
      setState(() {
        _repos[url] = _RepoReady(url, repo);
        _rebuildController();
      });
    } catch (e, stack) {
      logger.e('Failed to load repo $url', error: e, stackTrace: stack);
      if (!mounted || generation != _resolveGeneration) {
        return;
      }
      // No controller rebuild: the set of contributing repos is unchanged,
      // so already-loaded catalog pages must survive the failure.
      setState(() {
        _repos[url] = _RepoFailed(url, e);
      });
    }
  }

  void _rebuildController() {
    _controller?.dispose();
    _controller = null;
    if (_updatesOnly) {
      return;
    }
    final ready = _repos.values
        .whereType<_RepoReady>()
        .where((r) => _selectedRepoUrl == null || r.url == _selectedRepoUrl)
        .toList(growable: false);
    final sources = ready.map((r) {
      final source = r.repo.adapter.getRepoDataSource(r.repo.data);
      source.name = r.label;
      return source;
    }).toList();
    if (sources.isEmpty) {
      return;
    }
    _controller = DataSourceController<src.RemoteExtension>(sources);
  }

  void _setFilters(ExtensionFilters next) {
    setState(() {
      _filters = next;
    });
  }

  /// Languages currently on offer, gathered from the catalog items loaded so
  /// far (or the pending updates when the updates-only filter is active).
  Set<String> _availableLanguages() {
    final updateService = locate<ExtensionUpdateService>();
    if (_updatesOnly) {
      return {for (final e in updateService.updates.value.values) ...e.lang};
    }
    final langs = <String>{};
    final items = _controller?.items;
    if (items != null) {
      for (final item in items) {
        langs.addAll(
          item.fold(
            onSuccess: (e) => e.lang,
            onFailure: (_, _) => const <String>[],
          ),
        );
      }
    }
    return langs;
  }

  @override
  Widget build(BuildContext context) {
    final repos = settings.extension.repositories.value;
    if (repos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No repositories configured'),
            const SizedBox(height: 16),
            TextButton(
              // The repositories listener on this state re-resolves when the
              // dialog adds a repo, so nothing else is needed here.
              onPressed: () => showAddRepositoryDialog(context),
              child: const Text('Add Repository'),
            ),
          ],
        ),
      );
    }

    // Every repo failed and none is pending: nothing can be shown, offer a
    // global retry. Partial failures stay visible as failed chips instead.
    if (_hasFailed && !_hasReady && !_hasPending) {
      final failedUrls = _repos.values
          .whereType<_RepoFailed>()
          .map((r) => r.url)
          .join(', ');
      return Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: ErrorDisplay(
              e: Exception('Failed to load repositories: $failedUrls'),
              logError: false,
              actions: [ErrorAction(label: 'Retry', onTap: _resolveAll)],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildFilterBar(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildFilterBar() {
    final updateService = locate<ExtensionUpdateService>();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DionSpacing.sm,
        vertical: DionSpacing.xs,
      ),
      child: Column(
        children: [
          ExtensionFilterBar(
            searchController: _searchController,
            searchHint: 'Search available extensions',
            filters: _filters,
            languageOptions: _availableLanguages(),
            onChanged: _setFilters,
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(top: DionSpacing.xs),
            child: Row(
              children: [
                _repoChipAll(),
                for (final r in _repos.values) _repoChip(context, r),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(top: 2),
            child: ValueListenableBuilder<Map<String, src.RemoteExtension>>(
              valueListenable: updateService.updates,
              builder: (context, updateMap, _) {
                final updateCount = updateMap.length;
                return Row(
                  children: [
                    FilterChip(
                      label: Text(
                        updateCount > 0 ? 'Updates ($updateCount)' : 'Updates',
                      ),
                      showCheckmark: false,
                      selected: _updatesOnly,
                      onSelected: (selected) {
                        setState(() {
                          _updatesOnly = selected;
                          _rebuildController();
                        });
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _repoChipAll() {
    return Padding(
      padding: const EdgeInsets.only(right: DionSpacing.sm),
      child: FilterChip(
        label: const Text('All repositories'),
        showCheckmark: false,
        selected: _selectedRepoUrl == null,
        onSelected: (_) {
          setState(() {
            _selectedRepoUrl = null;
            _rebuildController();
          });
        },
      ),
    );
  }

  Widget _repoChip(BuildContext context, _RepoResolution r) {
    return Padding(
      padding: const EdgeInsets.only(right: DionSpacing.sm),
      child: switch (r) {
        final _RepoReady ready => FilterChip(
          selected: _selectedRepoUrl == ready.url,
          showCheckmark: false,
          avatar: const Icon(Icons.check_circle_outline, size: 18),
          label: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(ready.label, overflow: TextOverflow.ellipsis),
                ),
                Text(
                  ' (${ready.repo.adapter.name})',
                  style: context.bodySmall?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          onSelected: (selected) {
            setState(() {
              _selectedRepoUrl = selected ? ready.url : null;
              _rebuildController();
            });
          },
        ),
        _RepoLoading() => Tooltip(
          message: 'Loading ${r.url}',
          child: FilterChip(
            avatar: const SizedBox(
              width: 14,
              height: 14,
              child: DionProgressBar(),
            ),
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(r.url, overflow: TextOverflow.ellipsis),
            ),
            onSelected: null,
          ),
        ),
        final _RepoFailed failed => Tooltip(
          message: 'Failed to load ${failed.url} ($failed). Tap to retry.',
          child: FilterChip(
            avatar: Icon(
              Icons.error_outline,
              size: 18,
              color: context.theme.colorScheme.error,
            ),
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(failed.url, overflow: TextOverflow.ellipsis),
            ),
            onSelected: (_) => _resolveOne(failed.url, _resolveGeneration),
          ),
        ),
      },
    );
  }

  Widget _buildBody() {
    if (_updatesOnly) {
      return _buildUpdatesList();
    }
    final controller = _controller;
    if (controller == null) {
      return Center(
        child: _hasPending
            ? const DionProgressBar()
            : const Text('No extensions found'),
      );
    }
    return DynamicList<src.RemoteExtension>(
      key: ValueKey(_selectedRepoUrl),
      showDataSources: false,
      controller: controller,
      filter: _filters.matchesRemote,
      itemBuilder: (context, item) => RemoteExtensionTile(extension: item),
    );
  }

  Widget _buildUpdatesList() {
    final updateService = locate<ExtensionUpdateService>();
    return ValueListenableBuilder<Map<String, src.RemoteExtension>>(
      valueListenable: updateService.updates,
      builder: (context, updateMap, _) {
        final entries = updateMap.values.where(_filters.matchesRemote).toList();
        if (entries.isEmpty) {
          return Center(
            child: Text(
              updateMap.isEmpty
                  ? 'No updates available'
                  : 'No updates match the current filters',
            ),
          );
        }
        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, i) =>
              RemoteExtensionTile(extension: entries[i]),
        );
      },
    );
  }
}

class RemoteExtensionTile extends StatelessWidget {
  final src.RemoteExtension extension;
  const RemoteExtensionTile({super.key, required this.extension});

  @override
  Widget build(BuildContext context) {
    final sourceExt = locate<src.ExtensionService>();
    final updateService = locate<ExtensionUpdateService>();
    return ListenableBuilder(
      listenable: sourceExt,
      builder: (context, _) {
        final installed = sourceExt.tryGetExtension(extension.id);
        final canUpdate =
            installed != null &&
            parseVersion(extension.version) > installed.version;

        return DionListTile(
          leading: SizedBox(
            width: 40,
            height: 40,
            child: DionImage.fromLink(
              link: extension.cover,
              width: 40,
              height: 40,
              errorWidget: const Icon(Icons.extension),
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  extension.name,
                  style: context.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: DionSpacing.sm),
              Text(
                'v${extension.version}',
                style: context.bodySmall?.copyWith(
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (!extension.compatible)
                Text(
                  'Incompatible',
                  style: context.bodySmall?.copyWith(
                    color: context.theme.colorScheme.error,
                  ),
                ).paddingOnly(left: DionSpacing.sm),
            ],
          ),
          subtitle: ExtensionMetaChips(
            kinds: extension.extensionKinds,
            mediaTypes: extension.mediaType,
            nsfw: extension.nsfw,
            languages: extension.lang,
            iconOnlyKinds: true,
            maxLanguages: 3,
          ),
          trailing: installed == null
              ? DionIconbutton(
                  tooltip: 'Install',
                  icon: const Icon(Icons.download),
                  onPressed: () async {
                    if (await installExtensionWithConsent(
                      context,
                      extension: extension,
                    )) {
                      updateService.markUpdated(extension.id);
                    }
                  },
                )
              : canUpdate
              ? DionIconbutton(
                  tooltip: 'Update',
                  icon: const Icon(Icons.update),
                  onPressed: () async {
                    if (await installExtensionWithConsent(
                      context,
                      extension: extension,
                      installed: installed,
                    )) {
                      updateService.markUpdated(extension.id);
                    }
                  },
                )
              : const Icon(Icons.check, color: Colors.green),
        );
      },
    );
  }
}

class _AddRepositoryDialog extends StatefulWidget {
  const _AddRepositoryDialog();

  @override
  State<_AddRepositoryDialog> createState() => _AddRepositoryDialogState();
}

class _AddRepositoryDialogState extends State<_AddRepositoryDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    // Disposing here (instead of right after showDialog returns) is what
    // keeps the dialog's exit animation from touching a dead controller.
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Repository'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'https://...'),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _controller.text.trim().isEmpty ? null : _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

void _showFileInstallToast({
  required List<String> fileNames,
  required int installedCount,
  required int updatedCount,
  required List<String> failedFiles,
}) {
  final fileCount = fileNames.length;
  if (failedFiles.isEmpty) {
    if (fileCount == 1) {
      showToast(
        updatedCount > 0
            ? "Updated extension from '${fileNames.single}'"
            : "Installed extension from '${fileNames.single}'",
        src.ToastKind.success,
      );
      return;
    }
    final parts = <String>[
      if (installedCount > 0)
        'installed $installedCount extension${installedCount == 1 ? '' : 's'}',
      if (updatedCount > 0)
        'updated $updatedCount extension${updatedCount == 1 ? '' : 's'}',
    ];
    showToast('Successfully ${parts.join(' and ')}', src.ToastKind.success);
    return;
  }
  final failureMessage = failedFiles.length == 1
      ? "Failed to install '${failedFiles.single}'"
      : 'Failed to install ${failedFiles.length} extensions';
  if (installedCount + updatedCount == 0) {
    showToast(failureMessage, src.ToastKind.error);
    return;
  }
  final parts = <String>[
    if (installedCount > 0)
      'Installed $installedCount extension${installedCount == 1 ? '' : 's'}',
    if (updatedCount > 0)
      'updated $updatedCount extension${updatedCount == 1 ? '' : 's'}',
  ];
  showToast(
    '${parts.join(' and ')}, but ${failureMessage.replaceFirst('Failed', 'failed')}',
    src.ToastKind.warning,
  );
}

Future<void> showAddRepositoryDialog(BuildContext context) async {
  final res = await showDialog<String>(
    context: context,
    builder: (context) => const _AddRepositoryDialog(),
  );
  if (res == null || res.isEmpty) {
    return;
  }
  final repos = settings.extension.repositories.value;
  if (repos.contains(res)) {
    showToast('Repository already added', src.ToastKind.warning);
    return;
  }
  settings.extension.repositories.value = [...repos, res];
}
