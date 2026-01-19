import 'package:dionysos/data/settings/extension_setting.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/views/customui.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/settings/setting_dropdown.dart';
import 'package:dionysos/widgets/settings/setting_numberbox.dart';
import 'package:dionysos/widgets/settings/setting_slider.dart';
import 'package:dionysos/widgets/settings/setting_stringlist.dart';
import 'package:dionysos/widgets/settings/setting_textbox.dart';
import 'package:dionysos/widgets/settings/setting_toggle.dart';
import 'package:dionysos/widgets/settings/settings_multidropdown.dart';
import 'package:flutter/widgets.dart';

class DionRuntimeSettingView extends StatelessWidget {
  final Setting<dynamic, DionRuntimeSettingMetaData<dynamic>> setting;

  const DionRuntimeSettingView({super.key, required this.setting});

  @override
  Widget build(BuildContext context) {
    if (setting.metadata.ui != null) {
      switch (setting.metadata.ui!) {
        case final SettingsUI_CustomUI ui:
          return CustomUIWidget.fromUI(
            ui: ui.ui,
            extension: setting.metadata.extension,
          );
        case final SettingsUI_MultiDropdown _:
          return SettingsMultiDropdown<Object>(
            setting: setting.cast(),
            title: setting.metadata.label,
          );
        case final SettingsUI_CheckBox _:
          return SettingToggle(
            setting: setting.cast(),
            title: setting.metadata.label,
          );
        case final SettingsUI_Slider slider:
          return SettingSlider<double>(
            setting: setting.cast(),
            title: setting.metadata.label,
            min: slider.min,
            max: slider.max,
          );
        case final SettingsUI_Dropdown _:
          return SettingDropdown<dynamic>(
            setting: setting.cast(),
            title: setting.metadata.label,
          );
      }
    }
    switch (setting.value) {
      case String _:
        return SettingTextbox(
          setting: setting.cast(),
          title: setting.metadata.label,
        );
      case double _:
        return SettingNumberbox<double>(
          setting: setting.cast(),
          title: setting.metadata.label,
        );
      case bool _:
        return SettingToggle(
          setting: setting.cast(),
          title: setting.metadata.label,
        );
      case List<String> _:
        return SettingStringList(setting: setting.cast());
      case _:
        return ErrorDisplay(
          e: Exception('Unknown Setting type ${setting.value.runtimeType}'),
          message: 'Setting key ${setting.metadata.id} unexpected Runtime type',
        );
    }
  }
}
