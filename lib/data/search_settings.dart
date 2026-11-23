import 'package:dionysos/data/search_profile.dart';
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:flutter/foundation.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

SearchProfile? get activeSearchProfile {
  final activeId = settings.extension.activeSearchProfile.value;
  return settings.extension.searchProfiles.value
      .where((p) => p.id == activeId)
      .firstOrNull;
}

Map<String, rust.Setting> activeSearchSettings(String extensionId) {
  final fallback =
      settings.extension.searchSettings.value[extensionId] ?? const {};
  return activeSearchProfile?.settings[extensionId] ?? fallback;
}

void setActiveSearchSettings(
  String extensionId,
  Map<String, rust.Setting> value,
) {
  if (mapEquals(activeSearchSettings(extensionId), value)) return;
  final profile = activeSearchProfile;
  if (profile == null) {
    final current = settings.extension.searchSettings;
    current.value = {...current.value, extensionId: value};
    return;
  }
  final profiles = settings.extension.searchProfiles;
  profiles.value = [
    for (final p in profiles.value)
      if (p.id == profile.id)
        p.copyWith(settings: {...p.settings, extensionId: value})
      else
        p,
  ];
}

void storeReturnedSearchSettings(
  String extensionId,
  Map<String, rust.Setting> sent,
  Map<String, rust.Setting> returned,
) {
  final current = activeSearchSettings(extensionId);
  setActiveSearchSettings(
    extensionId,
    identical(current, sent)
        ? returned
        : mergeSearchSettingValues(returned, current),
  );
}

SearchSettings snapshotSearchSettings(Iterable<String> extensionIds) => {
  for (final id in extensionIds)
    if (activeSearchSettings(id) case final s when s.isNotEmpty) id: s,
};
