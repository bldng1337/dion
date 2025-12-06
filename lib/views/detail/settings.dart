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
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:dionysos/widgets/settings/setting_toggle.dart';
import 'package:flutter/material.dart' show showDialog;
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
    return Padding(
      padding: const EdgeInsets.all(15),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingTitle(title: 'Entry Settings'),
            if (controller != null)
              DionMultiDropdown(
                defaultItem: const Text('Choose a category'),
                controller: controller,
                onSelectionChange: (selection) {
                  widget.entry.categories = selection;
                },
              ).paddingAll(10),
            SettingTitle(
              title: 'Episodes',
              children: [
                SettingToggle(
                  title: 'Reverse Order',
                  setting: widget.entry.savedSettings.reverse,
                ),
                SettingToggle(
                  title: 'Hide Finished Episodes',
                  setting: widget.entry.savedSettings.hideFinishedEpisodes,
                ),
                SettingToggle(
                  title: 'Only Show Bookmarked Episodes',
                  setting: widget.entry.savedSettings.onlyShowBookmarked,
                ),
              ],
            ),
            SettingTitle(
              title: 'Downloads',
              children: [
                SettingSlider(
                  title: 'Autodownload Next Episodes',
                  setting: widget.entry.savedSettings.downloadNextEpisodes,
                  min: 0,
                  max: 10,
                ),
                SettingToggle(
                  title: 'Delete On Finish',
                  setting: widget.entry.savedSettings.deleteOnFinish,
                ),
              ],
            ),

            if (extsettings.isNotEmpty)
              SettingTitle(
                title: 'Extension Settings',
                children: [
                  for (final setting in extsettings)
                    DionRuntimeSettingView(setting: setting),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
