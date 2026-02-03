import 'dart:async';

import 'package:dionysos/data/versioning.dart';
import 'package:metis/adapter/dataclass.dart';
import 'package:metis/metis.dart';

class ExtensionMetaData with DBConstClass {
  final String id;
  final bool enabled;
  final bool searchEnabled;
  const ExtensionMetaData(this.id, this.enabled, {this.searchEnabled = true});
  const ExtensionMetaData.empty(String id) : this(id, false);

  @override
  String toString() {
    return 'ExtensionMetaData{id: $id, enabled: $enabled, searchEnabled: $searchEnabled}';
  }

  ExtensionMetaData copyWith({String? id, bool? enabled, bool? searchEnabled}) {
    return ExtensionMetaData(
      id ?? this.id,
      enabled ?? this.enabled,
      searchEnabled: searchEnabled ?? this.searchEnabled,
    );
  }

  factory ExtensionMetaData.fromJson(Map<String, dynamic> json) =>
      ExtensionMetaData(
        (json['id'] as DBRecord).id as String,
        json['enabled'] as bool,
        searchEnabled: json['searchEnabled'] as bool? ?? true,
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
    };
  }
}

DBRecord constructExtensionDBRecord(String extid) =>
    DBRecord('extension', extid);
