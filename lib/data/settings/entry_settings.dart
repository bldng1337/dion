import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/settings/extension_setting.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

class EntrySettingMetaData<T> extends SettingMetaData<T>
    implements ExtensionSettingMetaData<T> {
  final EntrySaved entry;
  final String settingkey;
  const EntrySettingMetaData(this.entry, this.settingkey);

  @override
  void onChange(T val) {
    entry.setSetting(settingkey, val);
  }

  @override
  String get id => settingkey;

  @override
  rust.Setting get setting => entry.getSetting(settingkey)!;

  @override
  List<EnumValue<T>> get values => switch (setting.ui) {
    final rust.SettingUI_Dropdown dropdown =>
      dropdown.options.map((e) => EnumValue(e.label, e.value as T)).toList(),
    _ => throw UnimplementedError(
      'Setting UI type ${setting.ui.runtimeType} not supported for conversion in $runtimeType',
    ),
  };

  @override
  String getLabel(T value) => switch (setting.ui) {
    final rust.SettingUI_Dropdown dropdown =>
      dropdown.options.firstWhere((e) => e.value == value).label,
    _ => throw UnimplementedError(
      'Setting UI type ${setting.ui.runtimeType} not supported for label lookup in $runtimeType',
    ),
  };
}
