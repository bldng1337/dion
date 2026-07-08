import 'dart:io';

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/routes.dart';
import 'package:dionysos/service/extension.dart' as src;
import 'package:dionysos/service/extension_updates.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/version.dart';
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
        DropdownButton,
        DropdownMenuItem,
        FilterChip,
        Icons,
        TextButton,
        TextField,
        showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';

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
            try {
              setState(() {
                loading = true;
              });
              const XTypeGroup typeGroup = XTypeGroup(
                label: 'Extensions',
                extensions: <String>['js', 'apk'],
              );
              final List<XFile> files = await openFiles(
                acceptedTypeGroups: <XTypeGroup>[typeGroup],
              );
              for (final xfile in files) {
                final file = File(xfile.path);
                await sourceExt.install(file.fileURL);
              }
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

class ExtensionList extends StatelessWidget {
  const ExtensionList({super.key});

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
        final exts = sourceExt.getExtensions().toList(growable: false);
        if (exts.isEmpty) {
          return const Center(child: Text('No extensions installed'));
        }
        return ValueListenableBuilder<Map<String, src.RemoteExtension>>(
          valueListenable: updateService.updates,
          builder: (context, updateMap, _) {
            return ListView.builder(
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
                              errorWidget: const Icon(Icons.image, size: 30),
                            ),
                          ),
                          if (ext.loading) const DionProgressBar(),
                        ],
                      ),
                    ),
                    title: Text(
                      ext.name,
                      style: context.titleMedium!.copyWith(
                        color: ext.isenabled
                            ? context.theme.colorScheme.primary
                            : Colors.grey,
                      ),
                    ),
                    onTap: () => ext.toggle(),
                    onLongTap: () => context.push('/extension/${ext.data.id}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${ext.data.desc ?? ''} v${ext.data.version}'),
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
            );
          },
        );
      },
    );
  }
}

class _ResolvedRepo {
  final String url;
  final src.RemoteExtensionRepo repo;
  _ResolvedRepo(this.url, this.repo);

  String get sourceType => repo.adapter.name;
}

class ExtensionCatalog extends StatefulWidget {
  const ExtensionCatalog({super.key});

  @override
  State<ExtensionCatalog> createState() => _ExtensionCatalogState();
}

class _ExtensionCatalogState extends State<ExtensionCatalog>
    with StateDisposeScopeMixin {
  List<_ResolvedRepo> _resolved = [];

  String? _selectedRepoUrl;

  String? _selectedSourceType;

  bool _updatesOnly = false;

  DataSourceController<src.RemoteExtension>? _controller;

  @override
  void initState() {
    super.initState();
    _resolveRepos();
  }

  Future<void> _resolveRepos() async {
    final repos = settings.extension.repositories.value;
    final sourceExt = locate<src.ExtensionService>();
    setState(() {
      _resolved = [];
      if (_selectedRepoUrl != null) {
        _selectedRepoUrl = null;
      }
      _rebuildController();
    });
    for (final url in repos) {
      try {
        sourceExt.getRepo(url).then((repo) {
          if (!mounted) {
            return;
          }
          setState(() {
            _resolved.add(_ResolvedRepo(url, repo));
            _rebuildController();
          });
        });
      } catch (e) {
        logger.e('Failed to load repo $url', error: e);
      }
    }
  }

  void _rebuildController() {
    final resolved = _resolved;
    if (resolved == null || resolved.isEmpty || _updatesOnly) {
      _controller = null;
      return;
    }
    final effective = effectiveRepos(resolved);
    if (effective.isEmpty) {
      _controller = null;
      return;
    }
    final sources = effective.map((r) {
      final source = r.repo.adapter.getRepoDataSource(r.repo.data);
      source.name = r.repo.data.name.isNotEmpty ? r.repo.data.name : r.url;
      return source;
    }).toList();
    _controller = DataSourceController<src.RemoteExtension>(sources);
  }

  List<_ResolvedRepo> effectiveRepos(List<_ResolvedRepo> resolved) {
    return resolved.where((r) {
      final matchesRepo = _selectedRepoUrl == null || r.url == _selectedRepoUrl;
      final matchesSource =
          _selectedSourceType == null || r.sourceType == _selectedSourceType;
      return matchesRepo && matchesSource;
    }).toList();
  }

  void _applyFilter() {
    setState(_rebuildController);
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
              onPressed: () async {
                await showAddRepositoryDialog(context);
                if (mounted) {
                  _resolveRepos();
                }
              },
              child: const Text('Add Repository'),
            ),
          ],
        ),
      );
    }

    final resolved = _resolved;
    if (resolved.isEmpty) {
      return const Center(child: DionProgressBar());
    }

    return Column(
      children: [
        _buildFilterBar(resolved),
        Expanded(child: _buildBody(resolved)),
      ],
    );
  }

  Widget _buildFilterBar(List<_ResolvedRepo> resolved) {
    final sourceTypes = resolved.map((r) => r.sourceType).toSet().toList();
    final updateService = locate<ExtensionUpdateService>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: _selectedRepoUrl,
                  hint: const Text('All repositories'),
                  items: [
                    // value omitted -> null, meaning "all repositories"
                    const DropdownMenuItem<String?>(
                      child: Text('All repositories'),
                    ),
                    ...resolved.map(
                      (r) => DropdownMenuItem<String?>(
                        value: r.url,
                        child: Text(
                          r.repo.data.name.isNotEmpty
                              ? r.repo.data.name
                              : r.url,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    _selectedRepoUrl = val;
                    _applyFilter();
                  },
                ),
              ),
              DionIconbutton(
                tooltip: 'Refresh Repositories',
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  _resolveRepos();
                },
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ValueListenableBuilder<Map<String, src.RemoteExtension>>(
              valueListenable: updateService.updates,
              builder: (context, updateMap, _) {
                final updateCount = updateMap.length;
                return Row(
                  children: [
                    for (final type in sourceTypes)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(type),
                          selected: _selectedSourceType == type,
                          onSelected: (selected) {
                            _selectedSourceType = selected ? type : null;
                            _applyFilter();
                          },
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: FilterChip(
                        label: Text(
                          updateCount > 0
                              ? 'Updates ($updateCount)'
                              : 'Updates',
                        ),
                        selected: _updatesOnly,
                        onSelected: (selected) {
                          setState(() {
                            _updatesOnly = selected;
                            _rebuildController();
                          });
                        },
                      ),
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

  Widget _buildBody(List<_ResolvedRepo> resolved) {
    if (_updatesOnly) {
      return _buildUpdatesList();
    }
    final controller = _controller;
    if (controller == null) {
      return const Center(child: Text('No extensions found'));
    }
    return DynamicList<src.RemoteExtension>(
      key: ValueKey('$_selectedRepoUrl|$_selectedSourceType'),
      showDataSources: false,
      controller: controller,
      itemBuilder: (context, item) => RemoteExtensionTile(extension: item),
    );
  }

  Widget _buildUpdatesList() {
    final updateService = locate<ExtensionUpdateService>();
    return ValueListenableBuilder<Map<String, src.RemoteExtension>>(
      valueListenable: updateService.updates,
      builder: (context, updateMap, _) {
        var entries = updateMap.values.toList();
        if (_selectedSourceType != null) {
          entries = entries
              .where((e) => e.adapter.name == _selectedSourceType)
              .toList();
        }
        if (entries.isEmpty) {
          return const Center(child: Text('No updates available'));
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
              errorWidget: const Icon(Icons.extension),
            ),
          ),
          title: Text(extension.name),
          subtitle: Text(
            'v${extension.version}${extension.compatible ? '' : ' (Incompatible)'}',
          ),
          trailing: installed == null
              ? DionIconbutton(
                  tooltip: 'Install',
                  icon: const Icon(Icons.download),
                  onPressed: () async {
                    await extension.install();
                    updateService.markUpdated(extension.id);
                  },
                )
              : canUpdate
              ? DionIconbutton(
                  tooltip: 'Update',
                  icon: const Icon(Icons.update),
                  onPressed: () async {
                    await extension.install();
                    updateService.markUpdated(extension.id);
                  },
                )
              : const Icon(Icons.check, color: Colors.green),
        );
      },
    );
  }
}

Future<void> showAddRepositoryDialog(BuildContext context) async {
  final controller = TextEditingController();
  final res = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add Repository'),
      content: TextField(
        controller: controller,
        // decoration: const InputDecoration(hintText: 'https://...'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Add'),
        ),
      ],
    ),
  );
  if (res != null && res.isNotEmpty) {
    settings.extension.repositories.value = [
      ...settings.extension.repositories.value,
      res,
    ];
  }
}
