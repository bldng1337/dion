import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/settings.dart' as appsettings;
import 'package:dionysos/widgets/settings/setting_numberbox.dart';
import 'package:dionysos/widgets/settings/setting_slider.dart';
import 'package:dionysos/widgets/settings/setting_textbox.dart';
import 'package:dionysos/widgets/settings/setting_toggle.dart';
import 'package:flutter/widgets.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

extension SettingvalueExtension on Settingvalue {
  Settingvalue updateWith(dynamic value) {
    return switch ((value, this)) {
      (final num val, final Settingvalue_Number settingval) =>
        Settingvalue_Number(
          val: val.toDouble(),
          defaultVal: settingval.defaultVal,
        ),
      (final String val, final Settingvalue_String settingval) =>
        Settingvalue_String(val: val, defaultVal: settingval.defaultVal),
      (final bool val, final Settingvalue_Boolean settingval) =>
        Settingvalue_Boolean(val: val, defaultVal: settingval.defaultVal),
      _ => throw UnimplementedError(
          'Settingvalue conversion for $runtimeType not implemented',
        ),
    };
  }
}

extension DymanicSetting on dynamic {
  Settingvalue toSettingvalue() => switch (this) {
        final Settingvalue val => val,
        final num val =>
          Settingvalue_Number(val: val.toDouble(), defaultVal: val.toDouble()),
        final String val => Settingvalue_String(val: val, defaultVal: val),
        final bool val => Settingvalue_Boolean(val: val, defaultVal: val),
        _ => throw UnimplementedError(
            'Settingvalue conversion for $runtimeType not implemented',
          ),
      };
}

extension SettingExtension on rust.Setting {
  appsettings.Setting<dynamic, T>
      toSetting<T extends appsettings.SettingMetaData>(T meta) => switch (val) {
            final rust.Settingvalue_String val => appsettings.Setting.fromValue(
                val.defaultVal,
                val.val,
                meta,
              ),
            final rust.Settingvalue_Number val => appsettings.Setting.fromValue(
                val.defaultVal,
                val.val,
                meta,
              ),
            final rust.Settingvalue_Boolean val =>
              appsettings.Setting.fromValue(
                val.defaultVal,
                val.val,
                meta,
              ),
            _ => throw UnimplementedError(
                'Setting conversion for $runtimeType not implemented',
              ),
          };
}

abstract class ExtensionSettingMetaData<T>
    extends appsettings.SettingMetaData<T> {
  rust.Setting get setting;
  String get id;
}

class ExtensionSettingView<T extends ExtensionSettingMetaData>
    extends StatelessWidget {
  final appsettings.Setting<dynamic, ExtensionSettingMetaData<dynamic>> setting;
  const ExtensionSettingView({super.key, required this.setting});

  @override
  Widget build(BuildContext context) {
    if (setting.metadata.setting.ui != null) {
      return switch (setting.metadata.setting.ui) {
        final SettingUI_Slider slider => SettingSlider(
            title: slider.label,
            setting: setting.cast<double, ExtensionSettingMetaData<double>>(),
            max: slider.max,
            min: slider.min, //TODO: step
          ),
        final SettingUI_Checkbox checkbox => SettingToggle(
            title: checkbox.label,
            setting: setting.cast<bool, ExtensionSettingMetaData<bool>>(),
          ),
        final SettingUI_Textbox textbox => SettingTextbox(
            title: textbox.label,
            setting: setting.cast<String, ExtensionSettingMetaData<String>>(),
          ),
        final SettingUI_Dropdown setting =>
          Text('Dropdown: ${setting.label}'), //TODO: implement dropdown
        _ => Text(
            'Setting: ${setting.metadata.id} has no known type ${setting.runtimeType}',
          ),
      };
    }
    return switch (setting.intialValue) {
      final int _ => SettingNumberbox(
          title: setting.metadata.id,
          setting: setting.cast<int, ExtensionSettingMetaData<int>>(),
        ),
      final double _ => SettingNumberbox(
          title: setting.metadata.id,
          setting: setting.cast<double, ExtensionSettingMetaData<double>>(),
        ),
      final bool _ => SettingToggle(
          title: setting.metadata.id,
          setting: setting.cast<bool, ExtensionSettingMetaData<bool>>(),
        ),
      final String _ => SettingTextbox(
          title: setting.metadata.id,
          setting: setting.cast<String, ExtensionSettingMetaData<String>>(),
        ),
      _ => Text(
          'Setting: ${setting.metadata.id} has no known type ${setting.runtimeType}',
        ),
    };
  }
}
