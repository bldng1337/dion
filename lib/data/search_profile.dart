import 'package:flutter/foundation.dart';

@immutable
class SearchProfile {
  final String id;
  final String name;
  final Set<String> enabled;

  const SearchProfile({
    required this.id,
    required this.name,
    this.enabled = const {},
  });

  SearchProfile copyWith({String? name, Set<String>? enabled}) {
    return SearchProfile(
      id: id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SearchProfile &&
      id == other.id &&
      name == other.name &&
      setEquals(enabled, other.enabled);

  @override
  int get hashCode => Object.hash(id, name, Object.hashAllUnordered(enabled));

  @override
  String toString() => 'SearchProfile{id: $id, name: $name, enabled: $enabled}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'enabled': enabled.toList(),
  };

  factory SearchProfile.fromJson(Map<String, dynamic> json) {
    return SearchProfile(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      enabled: (json['enabled'] as List<dynamic>? ?? const [])
          .cast<String>()
          .toSet(),
    );
  }
}
