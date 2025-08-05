import 'dart:async';

import 'package:dionysos/data/versioning.dart';
import 'package:metis/adapter/dataclass.dart';
import 'package:metis/metis.dart';
import 'package:uuid/uuid.dart';

class Category with DBConstClass {
  final DBRecord id;
  final String name;

  const Category(this.name, this.id);

  factory Category.construct(String name) =>
      Category(name, DBRecord('category', const Uuid().v4()));

  Category copyWith({String? name, DBRecord? id}) {
    return Category(name ?? this.name, id ?? this.id);
  }

  Category.fromJson(Map<String, dynamic> json)
    : name = json['name'] as String,
      id = json['id'] as DBRecord;

  Map<String, dynamic> toJson() => {
    'version': categorySerializeVersion.current,
    'name': name,
    'id': id,
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
}
