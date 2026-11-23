import 'package:flutter/foundation.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

typedef SearchSettings = Map<String, Map<String, rust.Setting>>;

@immutable
class SearchProfile {
  final String id;
  final String name;
  final Set<String> enabled;

  final SearchSettings settings;

  const SearchProfile({
    required this.id,
    required this.name,
    this.enabled = const {},
    this.settings = const {},
  });

  SearchProfile copyWith({
    String? name,
    Set<String>? enabled,
    SearchSettings? settings,
  }) {
    return SearchProfile(
      id: id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      settings: settings ?? this.settings,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SearchProfile &&
      id == other.id &&
      name == other.name &&
      setEquals(enabled, other.enabled) &&
      searchSettingsEqual(settings, other.settings);

  @override
  int get hashCode => Object.hash(id, name, Object.hashAllUnordered(enabled));

  @override
  String toString() => 'SearchProfile{id: $id, name: $name, enabled: $enabled}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'enabled': enabled.toList(),
    'settings': searchSettingsToJson(settings),
  };

  factory SearchProfile.fromJson(Map<String, dynamic> json) {
    return SearchProfile(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      enabled: (json['enabled'] as List<dynamic>? ?? const [])
          .cast<String>()
          .toSet(),
      settings: searchSettingsFromJson(json['settings']),
    );
  }
}

bool searchSettingsEqual(SearchSettings a, SearchSettings b) {
  if (a.length != b.length) return false;
  for (final MapEntry(:key, :value) in a.entries) {
    final other = b[key];
    if (other == null || !mapEquals(value, other)) return false;
  }
  return true;
}

Map<String, dynamic> searchSettingsToJson(SearchSettings settings) => {
  for (final MapEntry(key: extensionId, value: map) in settings.entries)
    extensionId: {
      for (final MapEntry(:key, :value) in map.entries) key: value.toJson(),
    },
};

SearchSettings searchSettingsFromJson(Object? json) {
  if (json is! Map) return const {};
  return {
    for (final MapEntry(key: extensionId, value: map) in json.entries)
      if (map is Map)
        extensionId as String: {
          for (final MapEntry(:key, :value) in map.entries)
            key as String: rust.JsonSetting.fromJson(value),
        },
  };
}

Map<String, rust.Setting> mergeSearchSettingValues(
  Map<String, rust.Setting> definitions,
  Map<String, rust.Setting> values,
) {
  return {
    for (final MapEntry(:key, value: definition) in definitions.entries)
      key: switch (values[key]) {
        final current?
            when current.value.runtimeType == definition.value.runtimeType =>
          rust.Setting(
            label: definition.label,
            value: current.value,
            default_: definition.default_,
            visible: definition.visible,
            ui: definition.ui,
          ),
        _ => definition,
      },
  };
}
