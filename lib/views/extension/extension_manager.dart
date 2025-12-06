import 'dart:io';

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/routes.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/file_utils.dart';
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

  @override
  void initState() {
    super.initState();
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
            child: ExtensionList(),
            tab: const Text('Installed').paddingAll(6),
          ),
          // DionTab(
          //   child: ExtensionRepoList(future: future),
          //   tab: const Text('Available').paddingAll(6),
          // ),
        ],
      ),
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
