import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/Category.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/settings/extension_setting.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/container/listtile.dart';
import 'package:dionysos/widgets/dialog.dart';
import 'package:dionysos/widgets/dropdown/multi_dropdown.dart';
import 'package:dionysos/widgets/dropdown/single_dropdown.dart';
import 'package:dionysos/widgets/settings/dion_runtime.dart';
import 'package:dionysos/widgets/settings/setting_slider.dart';
import 'package:dionysos/widgets/settings/setting_toggle.dart';
import 'package:flutter/material.dart' show FontWeight, Icons, showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

void showSettingPopup(BuildContext context, EntrySaved entry) {
  showDialog(
    context: context,
    builder: (context) => DionDialog(child: SettingsPopup(entry: entry)),
  );
}

class SettingsPopup extends StatefulWidget {
  final EntrySaved entry;
  const SettingsPopup({super.key, required this.entry});

  @override
  State<SettingsPopup> createState() => _SettingsPopupState();
}

class _SettingsPopupState extends State<SettingsPopup>
    with StateDisposeScopeMixin {
  MultiDropdownController<Category>? controller;
  late final List<Setting<dynamic, EntrySettingMetaData<dynamic>>> extsettings;

  @override
  void initState() {
    super.initState();
    final db = locate<Database>();
    extsettings = widget.entry.extsettings;
    scope.addDispose(() async {
      await widget.entry.save();
      await widget.entry.extension?.save();
    });
    db.getCategories().then((categories) {
      if (categories.isEmpty) return;
      controller = MultiDropdownController<Category>();
      controller!.setItems(
        categories.map((e) => MultiDropdownItem(label: e.name, value: e)),
      );
      controller!.selectWhere((e) => widget.entry.categories.contains(e.value));
      if (!mounted) return;
      setState(() {});
    });
  }

  List<Extension> _getAvailableEntryExtensions() {
    final extensionService = locate<ExtensionService>();
    final addedIds = widget.entry.entryExtensions
        .map((e) => e.extensionId)
        .toSet();
    return extensionService
        .getExtensions()
        .where(
          (ext) =>
              ext.isenabled &&
              ext.getExtensionTypeOrNull<rust.ExtensionType_EntryProcessor>() !=
                  null &&
              !addedIds.contains(ext.id),
        )
        .toList();
  }

  List<Extension> _getAvailableSourceExtensions() {
    final extensionService = locate<ExtensionService>();
    final addedIds = widget.entry.sourceExtensions
        .map((e) => e.extensionId)
        .toSet();
    return extensionService
        .getExtensions()
        .where(
          (ext) =>
              ext.isenabled &&
              ext
                      .getExtensionTypeOrNull<
                        rust.ExtensionType_SourceProcessor
                      >() !=
                  null &&
              !addedIds.contains(ext.id),
        )
        .toList();
  }

  void _addEntryExtension(Extension extension) {
    setState(() {
      widget.entry.entryExtensions = [
        ...widget.entry.entryExtensions,
        EntryExtension(extensionId: extension.id, extensionSettings: {}),
      ];
    });
  }

  void _removeEntryExtension(int index) {
    setState(() {
      widget.entry.entryExtensions = [
        ...widget.entry.entryExtensions.sublist(0, index),
        ...widget.entry.entryExtensions.sublist(index + 1),
      ];
    });
  }

  void _addSourceExtension(Extension extension) {
    setState(() {
      widget.entry.sourceExtensions = [
        ...widget.entry.sourceExtensions,
        EntryExtension(extensionId: extension.id, extensionSettings: {}),
      ];
    });
  }

  void _removeSourceExtension(int index) {
    setState(() {
      widget.entry.sourceExtensions = [
        ...widget.entry.sourceExtensions.sublist(0, index),
        ...widget.entry.sourceExtensions.sublist(index + 1),
      ];
    });
  }

  List<Setting<dynamic, EntryExtensionSettingMetaData<dynamic>>>
  _getEntryExtensionSettings(EntryExtension entryExtension) {
    return entryExtension.extensionSettings.entries.map((e) {
      final meta = EntryExtensionSettingMetaData(
        entryExtension,
        e.key,
        e.value.label,
        e.value.visible,
        e.value.ui,
      );
      return Setting.fromValue(
        e.value.default_.data as dynamic,
        e.value.value.data,
        meta,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final availableEntryExtensions = _getAvailableEntryExtensions();
    final availableSourceExtensions = _getAvailableSourceExtensions();

    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      decoration: BoxDecoration(
        color: context.theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (controller != null) ...[
                      _buildSectionHeader(context, 'CATEGORIES'),
                      _buildCategorySection(context),
                      const SizedBox(height: 24),
                    ],
                    _buildSectionHeader(context, 'EPISODES'),
                    _buildEpisodesSection(context),
                    const SizedBox(height: 24),
                    _buildSectionHeader(context, 'DOWNLOADS'),
                    _buildDownloadsSection(context),
                    if (extsettings.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader(context, 'EXTENSION'),
                      _buildExtensionSection(context),
                    ],
                    const SizedBox(height: 24),
                    _buildSectionHeader(context, 'ENTRY EXTENSIONS'),
                    _buildEntryExtensionsSection(
                      context,
                      availableEntryExtensions,
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader(context, 'SOURCE EXTENSIONS'),
                    _buildSourceExtensionsSection(
                      context,
                      availableSourceExtensions,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return ClipRRect(
      child: Container(
        decoration: BoxDecoration(
          color: context.theme.colorScheme.primary.withValues(alpha: 0.08),
          border: Border(
            bottom: BorderSide(
              color: context.theme.colorScheme.onSurface.withValues(
                alpha: 0.06,
              ),
              width: 0.5,
            ),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Text(
          'SETTINGS',
          style: context.titleLarge?.copyWith(
            fontWeight: FontWeight.w400,
            letterSpacing: -0.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 2),
      child: Text(
        title,
        style: context.labelSmall?.copyWith(
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          color: context.theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildCategorySection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: context.theme.colorScheme.onSurface.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: DionMultiDropdown(
        defaultItem: Text(
          'Choose a category',
          style: context.bodyMedium?.copyWith(
            color: context.theme.colorScheme.onPrimary,
          ),
        ),
        controller: controller,
        onSelectionChange: (selection) {
          widget.entry.categories = selection;
        },
      ),
    );
  }

  Widget _buildEpisodesSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: context.theme.colorScheme.onSurface.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          SettingToggle(
            title: 'Reverse Order',
            setting: widget.entry.savedSettings.reverse,
          ),
          _buildDivider(context),
          SettingToggle(
            title: 'Hide Finished Episodes',
            setting: widget.entry.savedSettings.hideFinishedEpisodes,
          ),
          _buildDivider(context),
          SettingToggle(
            title: 'Only Show Bookmarked Episodes',
            setting: widget.entry.savedSettings.onlyShowBookmarked,
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadsSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: context.theme.colorScheme.onSurface.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          SettingSlider(
            title: 'Autodownload Next Episodes',
            setting: widget.entry.savedSettings.downloadNextEpisodes,
            min: 0,
            max: 10,
          ),
          _buildDivider(context),
          SettingToggle(
            title: 'Delete On Finish',
            setting: widget.entry.savedSettings.deleteOnFinish,
          ),
        ],
      ),
    );
  }

  Widget _buildExtensionSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: context.theme.colorScheme.onSurface.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < extsettings.length; i++) ...[
            DionRuntimeSettingView(setting: extsettings[i]),
            if (i < extsettings.length - 1) _buildDivider(context),
          ],
        ],
      ),
    );
  }

  Widget _buildEntryExtensionsSection(
    BuildContext context,
    List<Extension> availableExtensions,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: context.theme.colorScheme.onSurface.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.entry.entryExtensions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No entry extensions added',
                style: context.bodyMedium?.copyWith(
                  color: context.theme.colorScheme.onSurface.withValues(
                    alpha: 0.5,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          for (int i = 0; i < widget.entry.entryExtensions.length; i++) ...[
            _buildEntryExtensionItem(
              context,
              widget.entry.entryExtensions[i],
              i,
            ),
            if (i < widget.entry.entryExtensions.length - 1)
              _buildDivider(context),
          ],
          if (widget.entry.entryExtensions.isNotEmpty &&
              availableExtensions.isNotEmpty)
            _buildDivider(context),
          if (availableExtensions.isNotEmpty)
            _buildAddExtensionRow(
              context,
              availableExtensions,
              _addEntryExtension,
              'Add entry extension...',
            ),
        ],
      ),
    );
  }

  Widget _buildSourceExtensionsSection(
    BuildContext context,
    List<Extension> availableExtensions,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: context.theme.colorScheme.onSurface.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.entry.sourceExtensions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No source extensions added',
                style: context.bodyMedium?.copyWith(
                  color: context.theme.colorScheme.onSurface.withValues(
                    alpha: 0.5,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          for (int i = 0; i < widget.entry.sourceExtensions.length; i++) ...[
            _buildSourceExtensionItem(
              context,
              widget.entry.sourceExtensions[i],
              i,
            ),
            if (i < widget.entry.sourceExtensions.length - 1)
              _buildDivider(context),
          ],
          if (widget.entry.sourceExtensions.isNotEmpty &&
              availableExtensions.isNotEmpty)
            _buildDivider(context),
          if (availableExtensions.isNotEmpty)
            _buildAddExtensionRow(
              context,
              availableExtensions,
              _addSourceExtension,
              'Add source extension...',
            ),
        ],
      ),
    );
  }

  Widget _buildEntryExtensionItem(
    BuildContext context,
    EntryExtension entryExtension,
    int index,
  ) {
    final extension = entryExtension.extension;
    final extensionName = extension?.name ?? 'Unknown Extension';
    final settings = _getEntryExtensionSettings(entryExtension);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DionListTile(
          title: Text(
            extensionName,
            style: context.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: extension == null
              ? Text(
                  'Extension not found: ${entryExtension.extensionId}',
                  style: context.bodySmall?.copyWith(
                    color: context.theme.colorScheme.error,
                  ),
                )
              : null,
          trailing: DionIconbutton(
            icon: Icon(
              Icons.delete_outline,
              color: context.theme.colorScheme.error,
            ),
            onPressed: () => _removeEntryExtension(index),
          ),
        ),
        if (settings.isNotEmpty) ...[
          _buildDivider(context),
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              'Settings from $extensionName',
              style: context.labelSmall?.copyWith(
                color: context.theme.colorScheme.onSurface.withValues(
                  alpha: 0.5,
                ),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          for (int i = 0; i < settings.length; i++) ...[
            DionRuntimeSettingView(setting: settings[i]),
            if (i < settings.length - 1) _buildDivider(context),
          ],
        ],
      ],
    );
  }

  Widget _buildSourceExtensionItem(
    BuildContext context,
    EntryExtension entryExtension,
    int index,
  ) {
    final extension = entryExtension.extension;
    final extensionName = extension?.name ?? 'Unknown Extension';
    final settings = _getEntryExtensionSettings(entryExtension);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DionListTile(
          title: Text(
            extensionName,
            style: context.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: extension == null
              ? Text(
                  'Extension not found: ${entryExtension.extensionId}',
                  style: context.bodySmall?.copyWith(
                    color: context.theme.colorScheme.error,
                  ),
                )
              : null,
          trailing: DionIconbutton(
            icon: Icon(
              Icons.delete_outline,
              color: context.theme.colorScheme.error,
            ),
            onPressed: () => _removeSourceExtension(index),
          ),
        ),
        if (settings.isNotEmpty) ...[
          _buildDivider(context),
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              'Settings from $extensionName',
              style: context.labelSmall?.copyWith(
                color: context.theme.colorScheme.onSurface.withValues(
                  alpha: 0.5,
                ),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          for (int i = 0; i < settings.length; i++) ...[
            DionRuntimeSettingView(setting: settings[i]),
            if (i < settings.length - 1) _buildDivider(context),
          ],
        ],
      ],
    );
  }

  Widget _buildAddExtensionRow(
    BuildContext context,
    List<Extension> availableExtensions,
    void Function(Extension) onAdd,
    String hintText,
  ) {
    Extension? selectedExtension;

    return StatefulBuilder(
      builder: (context, setLocalState) => Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: DionDropdown<Extension?>(
                items: [
                  DionDropdownItem<Extension?>(value: null, label: hintText),
                  ...availableExtensions.map(
                    (e) =>
                        DionDropdownItem<Extension?>(value: e, label: e.name),
                  ),
                ],
                value: selectedExtension,
                onChanged: (value) {
                  setLocalState(() {
                    selectedExtension = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            DionIconbutton(
              icon: const Icon(Icons.add),
              onPressed: selectedExtension != null
                  ? () {
                      onAdd(selectedExtension!);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Container(
      height: 0.5,
      width: double.infinity,
      color: context.theme.colorScheme.onSurface.withValues(alpha: 0.06),
    );
  }
}
