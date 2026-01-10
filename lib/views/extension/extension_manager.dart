import 'dart:io';

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/routes.dart';
import 'package:dionysos/service/extension.dart' as src;
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
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
        Icons,
        TextButton,
        TextField,
        showDialog;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:pub_semver/pub_semver.dart';

class ExtensionManager extends StatefulWidget {
  const ExtensionManager({super.key});

  @override
  _ExtensionManagerState createState() => _ExtensionManagerState();
}

class _ExtensionManagerState extends State<ExtensionManager> {
  bool loading = false;
  Object? error;
  final ValueNotifier<Map<String, src.RemoteExtension>> updates = ValueNotifier(
    {},
  );
  bool checkingUpdates = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    if (checkingUpdates) return;
    setState(() {
      checkingUpdates = true;
    });
    final sourceExt = locate<src.ExtensionService>();
    final repos = settings.extension.repositories.value;
    final installed = sourceExt.getExtensions();
    final installedIds = installed.map((e) => e.id).toSet();
    final Map<String, src.RemoteExtension> foundUpdates = {};

    for (final repoUrl in repos) {
      try {
        final repo = await sourceExt.getRepo(repoUrl);
        int page = 1;
        bool hasNext = true;
        while (hasNext) {
          final res = await repo.browse(page: page);
          for (final remote in res) {
            if (installedIds.contains(remote.id)) {
              final inst = installed.firstWhere((e) => e.id == remote.id);
              if (Version.parse(remote.version) > inst.version) {
                foundUpdates[remote.id] = remote;
              }
            }
          }
          if (res.isEmpty) hasNext = false;
          page++;
          if (page > 5) break; // Limit to 5 pages per repo for update check
        }
      } catch (e) {
        logger.e('Update check failed for $repoUrl', error: e);
      }
    }

    updates.value = foundUpdates;
    if (mounted) {
      setState(() {
        checkingUpdates = false;
      });
    }
  }

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
        DionIconbutton(
          tooltip: 'Check for Updates',
          onPressed: _checkForUpdates,
          icon: checkingUpdates
              ? const SizedBox(width: 20, height: 20, child: DionProgressBar())
              : const Icon(Icons.update),
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
                extensions: <String>['js'],
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
            child: ExtensionList(updates: updates),
            tab: const Text('Installed').paddingAll(6),
          ),
          DionTab(
            child: const ExtensionRepoBrowser(),
            tab: const Text('Available').paddingAll(6),
          ),
        ],
      ),
    );
  }
}

class ExtensionList extends StatelessWidget {
  final ValueNotifier<Map<String, src.RemoteExtension>> updates;
  const ExtensionList({super.key, required this.updates});

  @override
  Widget build(BuildContext context) {
    final sourceExt = locate<src.ExtensionService>();
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
        return ValueListenableBuilder(
          valueListenable: updates,
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
                              await sourceExt.install(update.remoteId);
                              updates.value = {
                                ...updates.value..remove(ext.id),
                              };
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

class ExtensionRepoBrowser extends StatefulWidget {
  const ExtensionRepoBrowser({super.key});

  @override
  State<ExtensionRepoBrowser> createState() => _ExtensionRepoBrowserState();
}

class _ExtensionRepoBrowserState extends State<ExtensionRepoBrowser> {
  String? selectedRepo;
  DataSourceController<src.RemoteExtension>? controller;

  @override
  void initState() {
    super.initState();
    _initRepo();
  }

  void _initRepo() {
    final repos = settings.extension.repositories.value;
    if (repos.isNotEmpty) {
      selectedRepo = repos.first;
      _updateController();
    }
  }

  Future<void> _updateController() async {
    if (selectedRepo == null) return;
    final sourceExt = locate<src.ExtensionService>();
    try {
      final repo = await sourceExt.getRepo(selectedRepo!);
      final dataSource = sourceExt.getRepoDataSources(repo);
      if (mounted) {
        setState(() {
          controller = DataSourceController(dataSource);
        });
      }
    } catch (e) {
      logger.e('Failed to load repo $selectedRepo', error: e);
    }
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
              onPressed: () {
                _showAddRepoDialog();
              },
              child: const Text('Add Repository'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              if (repos.length > 1)
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedRepo,
                    items: repos
                        .map(
                          (url) =>
                              DropdownMenuItem(value: url, child: Text(url)),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedRepo = val;
                        _updateController();
                      });
                    },
                  ),
                )
              else
                Expanded(
                  child: Text(
                    selectedRepo ?? '',
                    style: context.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              DionIconbutton(
                tooltip: 'Refresh Repository',
                icon: const Icon(Icons.refresh),
                onPressed: _updateController,
              ),
            ],
          ),
        ),
        Expanded(
          child: controller == null
              ? const Center(child: DionProgressBar())
              : DynamicList<src.RemoteExtension>(
                  showDataSources: false,
                  controller: controller!,
                  itemBuilder: (context, item) =>
                      RemoteExtensionTile(extension: item),
                ),
        ),
      ],
    );
  }

  Future<void> _showAddRepoDialog() async {
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
      setState(() {
        _initRepo();
      });
    }
  }
}

class RemoteExtensionTile extends StatelessWidget {
  final src.RemoteExtension extension;
  const RemoteExtensionTile({super.key, required this.extension});

  @override
  Widget build(BuildContext context) {
    final sourceExt = locate<src.ExtensionService>();
    return ListenableBuilder(
      listenable: sourceExt,
      builder: (context, _) {
        final installed = sourceExt.tryGetExtension(extension.id);
        final canUpdate =
            installed != null &&
            Version.parse(extension.version) > installed.version;

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
                  onPressed: () => sourceExt.install(extension.remoteId),
                )
              : canUpdate
              ? DionIconbutton(
                  tooltip: 'Update',
                  icon: const Icon(Icons.update),
                  onPressed: () => sourceExt.install(extension.remoteId),
                )
              : const Icon(Icons.check, color: Colors.green),
        );
      },
    );
  }
}
