import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/extension_repo.dart';
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/routes.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/async.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/listtile.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/tabbar.dart';
import 'package:dionysos/widgets/text_scroll.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart' show Colors, Icons;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

class ExtensionManager extends StatefulWidget {
  const ExtensionManager({super.key});

  @override
  _ExtensionManagerState createState() => _ExtensionManagerState();
}

class _ExtensionManagerState extends State<ExtensionManager> {
  bool loading = false;
  Object? error;
  late Future<List<ExtensionRepo>> future;

  Future<List<ExtensionRepo>> getRepos() async {
    final repos = settings.extension.repositories;
    return Future.wait(repos.value.map((e) => ExtensionRepo.fromURL(e)));
  }

  @override
  void initState() {
    super.initState();
    future = getRepos();
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
    final sourceExt = locate<SourceExtension>();

    return NavScaff(
      title: const DionTextScroll('Manage Extensions'),
      actions: [
        DionIconbutton(
          onPressed: () async {
            setState(() {
              loading = true;
            });
            try {
              future = getRepos();
              await sourceExt.reload();
              await future;
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
              final dir = await locateAsync<DirectoryProvider>();
              for (final file in files) {
                //I have no idea but android decides on some devices to rename dion.js to dion.es
                final filename = file.name.replaceAll('.dion.es', '.dion.js');
                await file.saveTo(
                  '${dir.extensionpath.absolute.path}/$filename',
                );
              }
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
          icon: const Icon(Icons.install_desktop),
        ),
      ],
      destination: homedestinations,
      child: DionTabBar(
        tabs: [
          DionTab(child: ExtensionList(), tab: const Text('Installed')),
          DionTab(
            child: ExtensionRepoList(future: future),
            tab: const Text('Available'),
          ),
        ],
      ),
    );
  }
}

class ExtensionRepoList extends StatelessWidget {
  final Future<List<ExtensionRepo>> future;
  const ExtensionRepoList({required this.future});

  @override
  Widget build(BuildContext context) {
    return LoadingBuilder(
      future: future,
      builder: (context, value) {
        final extensions = value.expand((e) => e.extensions).toList();
        final extmanager = locate<SourceExtension>();
        return ListenableBuilder(
          listenable: extmanager,
          builder: (context, child) => ListView.builder(
            itemCount: extensions.length,
            itemBuilder: (context, i) => RepoExtensionView(ext: extensions[i]),
          ),
        );
      },
    );
  }
}

class RepoExtensionView extends StatefulWidget {
  final RepoExtension ext;
  const RepoExtensionView({super.key, required this.ext});

  @override
  State<RepoExtensionView> createState() => _RepoExtensionViewState();
}

class _RepoExtensionViewState extends State<RepoExtensionView> {
  bool _loading = false;
  double? _progress;
  Object? _error;

  Widget getTrailing(BuildContext context) {
    if (_loading) {
      return DionProgressBar(value: _progress);
    }
    if (_error != null) {
      return DionIconbutton(
        icon: const Icon(Icons.error),
        tooltip: _error.toString(),
        onPressed: () {
          setState(() {
            _error = null;
          });
        },
      );
    }
    final installed = widget.ext.installed;
    if (installed == null) {
      return DionIconbutton(
        icon: const Icon(Icons.download),
        onPressed: () async {
          try {
            _loading = true;
            _progress = null;
            await widget.ext.install(
              onProgress: (p0) => setState(() {
                _progress = p0;
              }),
            );
            _loading = false;
          } catch (e, stack) {
            logger.e(e, stackTrace: stack);
            _error = e;
          }
        },
      );
    }
    if (installed.version < widget.ext.version) {
      return DionIconbutton(
        icon: const Icon(Icons.update),
        onPressed: () async {
          try {
            _loading = true;
            _progress = null;
            await widget.ext.install(
              onProgress: (p0) => setState(() {
                _progress = p0;
              }),
            );
            _loading = false;
          } catch (e, stack) {
            logger.e(e, stackTrace: stack);
            _error = e;
          }
        },
      );
    }
    return nil;
  }

  @override
  Widget build(BuildContext context) {
    return DionListTile(
      leading: DionImage(
        imageUrl: widget.ext.data.icon,
        width: 30,
        height: 30,
        errorWidget: const Icon(Icons.image, size: 30),
      ),
      title: Text(
        widget.ext.data.name,
        style: context.titleMedium!.copyWith(
          color: widget.ext.isinstalled
              ? context.theme.colorScheme.primary
              : Colors.grey,
        ),
      ),
      trailing: getTrailing(context),
      subtitle: Text('v${widget.ext.data.version}'),
    );
  }
}

class ExtensionList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sourceExt = locate<SourceExtension>();
    return ListenableBuilder(
      listenable: sourceExt,
      builder: (context, child) {
        if (sourceExt.loading) {
          return const Center(child: DionProgressBar());
        }
        final exts = sourceExt.getExtensions();
        return ListView.builder(
          itemCount: exts.length,
          itemBuilder: (context, i) => ListenableBuilder(
            listenable: exts[i],
            builder: (context, child) => DionListTile(
              leading: SizedBox(
                width: 30,
                height: 30,
                child: Stack(
                  children: [
                    Center(
                      child: DionImage(
                        imageUrl: exts[i].data.icon,
                        width: 30,
                        height: 30,
                        errorWidget: const Icon(Icons.image, size: 30),
                      ),
                    ),
                    if (exts[i].loading) const DionProgressBar(),
                  ],
                ),
              ),
              title: Text(
                exts[i].name,
                style: context.titleMedium!.copyWith(
                  color: exts[i].isenabled
                      ? context.theme.colorScheme.primary
                      : Colors.grey,
                ),
              ),
              onTap: () => exts[i].toggle(),
              onLongTap: () => context.push('/extension/${exts[i].data.id}'),
              subtitle: Text(
                '${exts[i].data.desc ?? ''} v${exts[i].data.version}',
              ),
            ),
          ),
        );
      },
    );
  }
}
