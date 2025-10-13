import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/settings/extension_setting.dart';
import 'package:dionysos/routes.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/cancel_token.dart';
import 'package:dionysos/utils/media_type.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/views/settings/library.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/card.dart';
import 'package:dionysos/widgets/context_menu.dart';
import 'package:dionysos/widgets/dialog.dart';
import 'package:dionysos/widgets/dropdown/single_dropdown.dart';
import 'package:dionysos/widgets/dynamic_grid.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/searchbar.dart';
import 'package:flutter/material.dart' show Colors, Icons, showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

abstract class BrowseInterface {
  List<Extension> get extensions;
  set extensions(List<Extension> value);
}

abstract class Filterable {
  Sort get sort;
  set sort(Sort value);
}

class Browse extends StatefulWidget {
  const Browse({super.key});

  @override
  _BrowseState createState() => _BrowseState();
}

class _BrowseState extends State<Browse>
    with StateDisposeScopeMixin
    implements BrowseInterface, Filterable {
  late final TextEditingController controller;
  late DataSourceController<Entry> datacontroller;
  late List<Extension> extension;
  late final CancelToken? token;

  Sort _sort = Sort.popular;

  @override
  Sort get sort => _sort;

  @override
  set sort(Sort value) {
    setState(() {
      _sort = value;
      datacontroller = DataSourceController<Entry>(
        extension
            .map(
              (e) =>
                  AsyncSource<Entry>((i) => e.browse(i, _sort))
                    ..name = e.data.name,
            )
            .toList(),
      );
      datacontroller.requestMore();
    });
  }

  @override
  List<Extension> get extensions => extension;

  @override
  set extensions(List<Extension> value) {
    setState(() {
      extension = value;
      datacontroller = DataSourceController<Entry>(
        extension
            .map(
              (e) =>
                  AsyncSource<Entry>((i) => e.browse(i, _sort))
                    ..name = e.data.name,
            )
            .toList(),
      );
      datacontroller.requestMore();
    });
  }

  @override
  void initState() {
    controller = TextEditingController()..disposedBy(scope);
    extensions = locate<SourceExtension>().getExtensions(
      extfilter: (e) => e.isenabled,
    );
    datacontroller = DataSourceController<Entry>(
      extensions
          .map(
            (e) =>
                AsyncSource<Entry>((i) => e.browse(i, _sort))
                  ..name = e.data.name,
          )
          .toList(),
    )..disposedBy(scope);
    token = CancelToken()..disposedBy(scope);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return NavScaff(
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
                icon: const Icon(Icons.settings),
                onPressed: () => showSettingPopup(context, this),
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
              setState(() {});
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
              setState(() {});
            },
          ),
        if (item is EntrySaved)
          ContextMenuItem(
            label: 'Remove from Library',
            onTap: () async {
              await (item as EntrySaved).delete();
              setState(() {});
            },
          ),
        if (item is EntrySaved)
          ContextMenuItem(
            label: 'Edit Categories',
            onTap: () async {
              showEditCategoriesDialog(context, item as EntrySaved);
            },
          ),
      ],
      child: EntryCard(entry: item, showSaved: widget.showSaved),
    );
  }
}

void showSettingPopup(BuildContext context, BrowseInterface browse) {
  showDialog(
    context: context,
    builder: (context) => DionDialog(child: SettingsPopup(browse: browse)),
  );
}

class SettingsPopup extends StatefulWidget {
  final BrowseInterface browse;
  const SettingsPopup({super.key, required this.browse});

  @override
  State<SettingsPopup> createState() => _SettingsPopupState();
}

class _SettingsPopupState extends State<SettingsPopup> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final filterable = widget.browse is Filterable
        ? widget.browse as Filterable
        : null;
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Search Settings'),
          if (filterable != null)
            DionDropdown<Sort>(
              value: filterable.sort,
              items: const [
                DionDropdownItem<Sort>(value: Sort.popular, label: 'Popular'),
                DionDropdownItem<Sort>(value: Sort.latest, label: 'Latest'),
                DionDropdownItem<Sort>(value: Sort.updated, label: 'Updated'),
              ],
              onChanged: (value) {
                if (value == null) return;
                filterable.sort = value;
                setState(() {});
              },
            ),
          for (final e in widget.browse.extensions) showExtension(context, e),
        ].notNullWidget(),
      ),
    );
  }

  Widget? showExtension(BuildContext context, Extension e) {
    if (e.loading ||
        !e.isenabled ||
        !e.settings.any(
          (s) => s.metadata.extsetting.settingtype == Settingtype.search,
        )) {
      return null;
    }
    return Padding(
      padding: const EdgeInsets.only(left: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DionImage(imageUrl: e.data.icon ?? '', width: 24, height: 24),
              Text(
                e.data.name,
                style: const TextStyle(fontSize: 16),
              ).paddingAll(10),
              const Spacer(),
              for (final MediaType mediatype in e.data.mediaType ?? [])
                Icon(mediatype.icon),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final setting in e.settings.where(
                  (s) =>
                      s.metadata.extsetting.settingtype == Settingtype.search,
                ))
                  ExtensionSettingView(setting: setting),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
