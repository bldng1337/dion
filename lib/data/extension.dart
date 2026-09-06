import 'dart:async';

import 'package:dionysos/data/versioning.dart';
import 'package:metis/adapter/dataclass.dart';
import 'package:metis/metis.dart';

class ExtensionMetaData with DBConstClass {
  final String id;
  final bool enabled;
  final bool searchEnabled;

  final List<String> autoAddRules;

  const ExtensionMetaData(
    this.id,
    this.enabled, {
    this.searchEnabled = true,
    this.autoAddRules = const [],
  });
  const ExtensionMetaData.empty(String id) : this(id, false);

  @override
  String toString() {
    return 'ExtensionMetaData{id: $id, enabled: $enabled, searchEnabled: $searchEnabled, autoAddRules: $autoAddRules}';
  }

  ExtensionMetaData copyWith({
    String? id,
    bool? enabled,
    bool? searchEnabled,
    List<String>? autoAddRules,
  }) {
    return ExtensionMetaData(
      id ?? this.id,
      enabled ?? this.enabled,
      searchEnabled: searchEnabled ?? this.searchEnabled,
      autoAddRules: autoAddRules ?? this.autoAddRules,
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
    };
  }
}

DBRecord constructExtensionDBRecord(String extid) =>
    DBRecord('extension', extid);
