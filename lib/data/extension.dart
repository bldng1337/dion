import 'dart:async';

import 'package:dionysos/data/versioning.dart';
import 'package:metis/adapter/dataclass.dart';
import 'package:metis/metis.dart';

class ExtensionMetaData with DBConstClass {
  final String id;
  final bool enabled;
  final bool searchEnabled;

  final List<String> autoAddRules;

  final bool removed;

  const ExtensionMetaData(
    this.id,
    this.enabled, {
    this.searchEnabled = true,
    this.autoAddRules = const [],
    this.removed = false,
  });
  const ExtensionMetaData.empty(String id) : this(id, false);

  @override
  String toString() {
    return 'ExtensionMetaData{id: $id, enabled: $enabled, searchEnabled: $searchEnabled, autoAddRules: $autoAddRules, removed: $removed}';
  }

  ExtensionMetaData copyWith({
    String? id,
    bool? enabled,
    bool? searchEnabled,
    List<String>? autoAddRules,
    bool? removed,
  }) {
    return ExtensionMetaData(
      id ?? this.id,
      enabled ?? this.enabled,
      searchEnabled: searchEnabled ?? this.searchEnabled,
      autoAddRules: autoAddRules ?? this.autoAddRules,
      removed: removed ?? this.removed,
    );
  }

  factory ExtensionMetaData.fromJson(Map<String, dynamic> json) =>
      ExtensionMetaData(
        (json['id'] as DBRecord).id as String,
        json['enabled'] as bool,
        searchEnabled: json['searchEnabled'] as bool? ?? true,
        autoAddRules:
            (json['autoAddRules'] as List<dynamic>?)?.cast<String>() ??
            const [],
        removed: json['removed'] as bool? ?? false,
      );

  @override
  DBRecord get dbId => constructExtensionDBRecord(id);

  @override
  FutureOr<Map<String, dynamic>> toDBJson() {
    return {
      'version': extensionSerializeVersion.current,
      'id': dbId,
      'enabled': enabled,
      'searchEnabled': searchEnabled,
      'autoAddRules': autoAddRules,
      if (removed) 'removed': true,
    };
  }
}

DBRecord constructExtensionDBRecord(String extid) =>
    DBRecord('extension', extid);
