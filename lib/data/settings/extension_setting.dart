import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/settings/settings.dart' as appsettings;
import 'package:dionysos/service/source_extension.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

extension SettingExtension on rust.Setting {
  rust.Setting copyWith({
    String? label,
    bool? visible,
    SettingValue? default_,
    SettingValue? value,
  }) {
    return rust.Setting(
      label: label ?? this.label,
      visible: visible ?? this.visible,
      default_: default_ ?? this.default_,
      value: value ?? this.value,
    );
  }
}

extension SettingvalueExtension on SettingValue {
  SettingValue updateWith(dynamic value) {
    return switch ((this, value)) {
      (final SettingValue_String _, final String value) => SettingValue.string(
        data: value,
      ),
      (final SettingValue_String _, final SettingValue_String value) =>
        SettingValue.string(data: value.data),
      (final SettingValue_Number _, final num value) => SettingValue.number(
        data: value.toDouble(),
      ),
      (final SettingValue_Number _, final SettingValue_Number value) =>
        SettingValue.number(data: value.data),
      (final SettingValue_Boolean _, final bool value) => SettingValue.boolean(
        data: value,
      ),
      (final SettingValue_Boolean _, final SettingValue_Boolean value) =>
        SettingValue.boolean(data: value.data),
      (final SettingValue_StringList _, final List<String> value) =>
        SettingValue.stringList(data: value),
      (final SettingValue_StringList _, final SettingValue_StringList value) =>
        SettingValue.stringList(data: value.data.toList()),
      _ => throw UnimplementedError(),
    };
  }
}

extension SettingValueExtension on dynamic {
  SettingValue get asSettingValue => switch (this) {
    final String data => SettingValue.string(data: data),
    final num data => SettingValue.number(data: data.toDouble()),
    final bool data => SettingValue.boolean(data: data),
    final List<String> data => SettingValue.stringList(data: data),
    _ => throw UnimplementedError(),
  };
}

extension SettingValueDoubleExtension on double {
  SettingValue get asSettingValue => SettingValue.number(data: this);
}

extension SettingValueStringExtension on String {
  SettingValue get asSettingValue => SettingValue.string(data: this);
}

extension SettingValueBoolExtension on bool {
  SettingValue get asSettingValue => SettingValue.boolean(data: this);
}

abstract class DionRuntimeSettingMetaData<T>
    extends appsettings.SettingMetaData<T>
    implements appsettings.EnumMetaData<T> {
  final String id;

  // Setting MetaData

  final String label;
  final bool visible;
  final SettingsUI? ui;

  DionRuntimeSettingMetaData(this.id, this.label, this.visible, this.ui);

  @override
  String getLabel(T value) => switch (ui) {
    final SettingsUI_Dropdown dropdown =>
      dropdown.options.firstWhere((e) => e.value == value).label,
    _ => throw Exception('getLabel for ${ui.runtimeType} not implemented'),
  };

  @override
  List<appsettings.EnumValue<T>> get values => switch (ui) {
    final SettingsUI_Dropdown dropdown =>
      dropdown.options
          .map((e) => appsettings.EnumValue<T>(e.label, e.value as T))
          .toList(),
    _ => throw UnimplementedError(
      'getLabel for ${ui.runtimeType} not implemented',
    ),
  };
}

class ExtensionSettingMetaData<T> extends DionRuntimeSettingMetaData<T> {
  final rust.ProxyExtension _extension;
  final SettingKind kind;
  ExtensionSettingMetaData(
    this.kind,
    this._extension,
    super.id,
    super.label,
    super.visible,
    super.ui,
  );

  @override
  void onChange(T t) {
    _extension.setSetting(id: id, kind: kind, value: t.asSettingValue);
    super.onChange(t);
  }
}

class EntrySettingMetaData<T> extends DionRuntimeSettingMetaData<T> {
  final EntrySaved _entry;
  EntrySettingMetaData(
    this._entry,
    super.id,
    super.label,
    super.visible,
    super.ui,
  );

  @override
  void onChange(T t) {
    _entry.setSetting(id, t.asSettingValue);
    super.onChange(t);
  }
}
