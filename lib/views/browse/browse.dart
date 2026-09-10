import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/routes.dart';
import 'package:dionysos/service/extension.dart'
    hide
        ContainerType,
        CrossAxisAlignment,
        EdgeInsets,
        MainAxisAlignment,
        MainAxisSize,
        TextStyle,
        WrapAlignment;
import 'package:dionysos/utils/safe_set_state.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/views/dialog/migrate.dart';
import 'package:dionysos/views/settings/library.dart';
import 'package:dionysos/views/settings/search_settings.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/container/card.dart';
import 'package:dionysos/widgets/context_menu.dart';
import 'package:dionysos/widgets/dynamic_grid.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/searchbar.dart';
import 'package:flutter/material.dart' show Colors, Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class Browse extends StatefulWidget {
  const Browse({super.key});

  @override
  _BrowseState createState() => _BrowseState();
}

class _BrowseState extends State<Browse>
    with StateDisposeScopeMixin
    implements BrowseInterface {
  late final TextEditingController controller;
  late DataSourceController<Entry> datacontroller;
  @override
  late List<Extension> extensions;

  @override
  Future<void> refresh() async {
    if (!mounted) return;
    datacontroller.dispose();
    setState(() {
      datacontroller = DataSourceController<Entry>(
        extensions.map((e) => e.browse()).toList(),
      );
      datacontroller.requestMore();
    });
  }

  @override
  void dispose() {
    unregisterBrowseFeed(this);
    datacontroller.dispose();
    super.dispose();
  }

  @override
  void initState() {
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
    datacontroller = DataSourceController<Entry>(
      extensions.map((e) => e.browse()).toList(),
    );
    registerBrowseFeed(this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      title: const Text('Browse'),
      destination: homedestinations,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DionSearchbar(
            controller: controller,
            hintText: 'Search',
            style: const WidgetStatePropertyAll(TextStyle(fontSize: 20)),
            keyboardType: TextInputType.text,
            hintStyle: const WidgetStatePropertyAll(
              TextStyle(color: Colors.grey),
            ),
            onSubmitted: (s) => context.go('/search/$s'),
            actions: [
              DionIconbutton(
                tooltip: 'Search Settings',
                icon: const Icon(Icons.settings),
                onPressed: () {
                  showSettingPopup(context);
                },
              ),
            ],
          ).paddingAll(5),
          DynamicGrid<Entry>(
            itemBuilder: (BuildContext context, item) =>
                EntryDisplay(entry: item),
            controller: datacontroller,
          ).expanded(),
        ],
      ),
    );
  }
}

class EntryDisplay extends StatefulWidget {
  final Entry entry;
  final bool showSaved;
  const EntryDisplay({super.key, required this.entry, this.showSaved = true});

  @override
  State<EntryDisplay> createState() => _EntryDisplayState();
}

class _EntryDisplayState extends State<EntryDisplay> {
  late Entry item;
  @override
  void initState() {
    item = widget.entry;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ContextMenu(
      contextItems: [
        if (item is! EntryDetailed)
          ContextMenuItem(
            label: 'Load Details',
            onTap: () async {
              item = await item.toDetailed();
              safeSetState();
            },
          ),
        ContextMenuItem(
          label: 'Open in Browser',
          onTap: () async {
            await launchUrl(Uri.parse(item.url));
          },
        ),
        if (item is! EntrySaved)
          ContextMenuItem(
            label: 'Add to Library',
            onTap: () async {
              item = await (await item.toDetailed()).toSaved();
              safeSetState();
            },
          ),
        if (item is EntrySaved)
          ContextMenuItem(
            label: 'Remove from Library',
            onTap: () async {
              await (item as EntrySaved).delete();
              safeSetState();
            },
          ),
        if (item is EntrySaved)
          ContextMenuItem(
            label: 'Edit Categories',
            onTap: () async {
              showEditCategoriesDialog(context, item as EntrySaved);
            },
          ),
        if (item is EntrySaved)
          ContextMenuItem(
            label: 'Migrate',
            onTap: () async {
              final migrated = await showMigrateEntryPage(
                context,
                item as EntrySaved,
              );
              if (migrated != null && context.mounted) {
                item = migrated;
                setState(() {});
              }
            },
          ),
      ],
      child: EntryCard(entry: item, showSaved: widget.showSaved),
    );
  }
}
