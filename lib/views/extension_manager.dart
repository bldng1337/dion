import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/routes.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/listtile.dart';
import 'package:dionysos/widgets/scaffold.dart';
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
