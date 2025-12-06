import 'dart:async';

import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/versioning.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/dynamic_grid.dart';
import 'package:metis/adapter/dataclass.dart';
import 'package:metis/metis.dart';
import 'package:uuid/uuid.dart';

class Category with DBConstClass {
  final DBRecord id;
  final String name;
  final int index;

  const Category(this.name, this.id, this.index);

  factory Category.construct(String name, int index) =>
      Category(name, DBRecord('category', const Uuid().v4()), index);

  Category copyWith({String? name, DBRecord? id, int? index}) {
    return Category(name ?? this.name, id ?? this.id, index ?? this.index);
  }

  Category.fromJson(Map<String, dynamic> json)
    : name = json['name'] as String,
      id = json['id'] as DBRecord,
      index = json['index'] as int? ?? 0;

  Map<String, dynamic> toJson() => {
    'version': categorySerializeVersion.current,
    'name': name,
    'id': id,
    'index': index,
  };

  @override
  bool operator ==(Object other) {
    return other is Category && other.name == name && other.id == id;
  }

  @override
  int get hashCode => Object.hash(name, id);

  @override
  DBRecord get dbId => id;

  @override
  FutureOr<Map<String, dynamic>> toDBJson() => toJson();

  DataSource<EntrySaved> getEntries() => SingleStreamSource(
    (i) => locate<Database>().getEntriesInCategory(this, i, 25),
  );
}
