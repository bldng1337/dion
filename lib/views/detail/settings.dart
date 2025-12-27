import 'dart:ui';

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/Category.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/settings/extension_setting.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/service.dart';

import 'package:dionysos/widgets/dialog.dart';
import 'package:dionysos/widgets/dropdown/multi_dropdown.dart';
import 'package:dionysos/widgets/settings/dion_runtime.dart';
import 'package:dionysos/widgets/settings/setting_slider.dart';
import 'package:dionysos/widgets/settings/setting_toggle.dart';
import 'package:flutter/material.dart' show showDialog, FontWeight;
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';

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

  @override
  Widget build(BuildContext context) {
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

  Widget _buildDivider(BuildContext context) {
    return Container(
      height: 0.5,
      width: double.infinity,
      color: context.theme.colorScheme.onSurface.withValues(alpha: 0.06),
    );
  }
}
