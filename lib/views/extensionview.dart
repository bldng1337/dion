import 'package:desktop_drop/desktop_drop.dart';
import 'package:dionysos/extension/extensionmanager.dart';
import 'package:dionysos/extension/jsextension.dart';
import 'package:dionysos/main.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Extensionview extends StatefulWidget {
  const Extensionview({super.key});

  @override
  _ExtensionviewState createState() => _ExtensionviewState();
}

class _ExtensionviewState extends State<Extensionview> {
  bool dragging = false;
  bool loading = false;
  @override
  Widget build(BuildContext context) {
    return Nav(
        actions: [
          IconButton(
              onPressed: () async {
                loading = true;
                setState(() {});
                await ExtensionManager().reload();
                if (!mounted) {
                  return;
                }
                loading = false;
                setState(() {});
              },
              icon: const Icon(Icons.refresh),),
          IconButton(
              onPressed: () async {
                const XTypeGroup typeGroup = XTypeGroup(
                  label: 'images',
                  extensions: <String>['dion.js'],
                );
                final List<XFile> files = await openFiles(
                    acceptedTypeGroups: <XTypeGroup>[typeGroup],);
                for (final file in files) {
                  await ExtensionManager()
                      .installString(await file.readAsString());
                }
                if (!mounted) {
                  return;
                }
                setState(() {});
              },
              icon: const Icon(Icons.install_desktop),),
        ],
        child: loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : DropTarget(
                onDragEntered: (details) => setState(() {
                  dragging = true;
                }),
                onDragExited: (details) => setState(() {
                  dragging = false;
                }),
                onDragDone: (details) {
                  for (final element in details.files) {
                    ExtensionManager()
                        .installlocal(element.path)
                        .then((value) => setState(() {}));
                  }
                },
                child: Stack(
                  children: [
                    Row(children: [
                      Expanded(
                          child: ListView.builder(
                        itemBuilder: (BuildContext context, int index) {
                          if (ExtensionManager().loaded.length <= index) {
                            return null;
                          }
                          return ExtensionItem(
                              ExtensionManager().loaded[index],);
                        },
                        itemCount: ExtensionManager().loaded.length,
                      ),),
                    ],),
                    if (dragging)
                      ColoredBox(
                        color: Theme.of(context)
                            .scaffoldBackgroundColor
                            .withOpacity(0.8),
                        child: const Center(
                            child: Text('Drop Here to install Extension'),),
                      ),
                  ],
                ),
              ),);
  }
}

/*

*/

class ExtensionItem extends StatefulWidget {
  final Extension e;
  const ExtensionItem(this.e, {super.key});

  @override
  _ExtensionItemState createState() => _ExtensionItemState();
}

class _ExtensionItemState extends State<ExtensionItem> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      isThreeLine: true,
      subtitle: Text(widget.e.data?.desc ?? ''),
      leading: FancyShimmerImage(
        width: 50,
        height: 50,
        imageUrl: widget.e.data?.icon ?? 'https://0.0.0.0/',
        errorWidget: const Icon(Icons.image, size: 50),
      ),
      title: Text(widget.e.data?.name ?? 'Unknown'),
      selected: widget.e.enabled,
      onTap: () => widget.e
          .setenabled(!widget.e.enabled)
          .then((value) => setState(() {})),
      onLongPress: () =>
          context.push('/manage/extensionsettings', extra: widget.e),
    );
  }
}
