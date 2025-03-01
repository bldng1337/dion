import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/routes.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/listtile.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:text_scroll/text_scroll.dart';

class ExtensionManager extends StatefulWidget {
  const ExtensionManager({super.key});

  @override
  _ExtensionManagerState createState() => _ExtensionManagerState();
}

class _ExtensionManagerState extends State<ExtensionManager> {
  @override
  Widget build(BuildContext context) {
    final sourceExt = locate<SourceExtension>();
    final exts = sourceExt.getExtensions();
    return NavScaff(
      title: const TextScroll('Manage Extensions'),
      actions: [
        IconButton(
            onPressed: () async {
              await sourceExt.reload();
              if (!mounted) {
                return;
              }
              setState(() {});
            },
            icon: const Icon(Icons.refresh)),
        IconButton(
          onPressed: () async {
            const XTypeGroup typeGroup = XTypeGroup(
              label: 'Extensions',
              extensions: <String>['dion.js'],
            );
            final List<XFile> files = await openFiles(
              acceptedTypeGroups: <XTypeGroup>[typeGroup],
            );
            for (final file in files) {
              final dir = await locateAsync<DirectoryProvider>();

              await file.saveTo('${dir.extensionpath.absolute.path}/${file.name}');
            }
            await sourceExt.reload();
            if (!mounted) {
              return;
            }
            setState(() {});
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
                      hasPopup: true,
                      errorWidget: const Icon(
                        Icons.image,
                        size: 30,
                      ),
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
            subtitle:
                Text('${exts[i].data.desc ?? ''} v${exts[i].data.version}'),
          ),
        ),
      ),
    );
  }
}
