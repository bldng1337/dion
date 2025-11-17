import 'dart:async';

import 'package:dionysos/data/versioning.dart';
import 'package:metis/adapter/dataclass.dart';
import 'package:metis/metis.dart';

class ExtensionMetaData with DBConstClass {
  final String id;
  final bool enabled;
  const ExtensionMetaData(this.id, this.enabled);
  const ExtensionMetaData.empty(String id) : this(id, false);

  @override
  String toString() {
    return 'ExtensionMetaData{id: $id, enabled: $enabled}';
  }

  ExtensionMetaData copyWith({String? id, bool? enabled}) {
    return ExtensionMetaData(id ?? this.id, enabled ?? this.enabled);
  }

  factory ExtensionMetaData.fromJson(Map<String, dynamic> json) =>
      ExtensionMetaData(
        (json['id'] as DBRecord).id as String,
        json['enabled'] as bool,
      );

  @override
  DBRecord get dbId => constructExtensionDBRecord(id);

  @override
  FutureOr<Map<String, dynamic>> toDBJson() {
    return {
      'version': extensionSerializeVersion.current,
      'id': dbId,
      'enabled': enabled,
    };
  }
}

DBRecord constructExtensionDBRecord(String extid) =>
    DBRecord('extension', extid);
