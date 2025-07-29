import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/routes.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/listtile.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/text_scroll.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
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
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final sourceExt = locate<SourceExtension>();
    final exts = sourceExt.getExtensions();
    return NavScaff(
      title: const DionTextScroll('Manage Extensions'),
      actions: [
        IconButton(
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
        IconButton(
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
      child: ListView.builder(
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
                  if (exts[i].loading) const CircularProgressIndicator(),
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
      ),
    );
  }
}
