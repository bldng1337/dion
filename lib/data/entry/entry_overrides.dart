import 'package:rdion_runtime/rdion_runtime.dart' as rust;

class EntryOverrides {
  final String? title;
  final List<String>? author;
  final String? description;
  final List<String>? genres;
  final rust.Link? cover;
  final rust.Link? poster;

  const EntryOverrides({
    this.title,
    this.author,
    this.description,
    this.genres,
    this.cover,
    this.poster,
  });

  static const none = EntryOverrides();

  bool get isEmpty =>
      title == null &&
      author == null &&
      description == null &&
      genres == null &&
      cover == null &&
      poster == null;

  List<String> applyTitles(List<String> titles) {
    final title = this.title;
    if (title == null) return titles;
    return [title, ...titles.where((t) => t != title)];
  }

  Map<String, dynamic>? toJson() {
    if (isEmpty) return null;
    return {
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (description != null) 'description': description,
      if (genres != null) 'genres': genres,
      if (cover != null) 'cover': _linkToJson(cover!),
      if (poster != null) 'poster': _linkToJson(poster!),
    };
  }

  factory EntryOverrides.fromJson(dynamic json) {
    if (json is! Map) return none;
    return EntryOverrides(
      title: json['title'] as String?,
      author: (json['author'] as List<dynamic>?)?.cast<String>(),
      description: json['description'] as String?,
      genres: (json['genres'] as List<dynamic>?)?.cast<String>(),
      cover: _linkFromJson(json['cover']),
      poster: _linkFromJson(json['poster']),
    );
  }

  static Map<String, dynamic> _linkToJson(rust.Link link) => {
    'url': link.url,
    if (link.header != null) 'header': link.header,
  };

  static rust.Link? _linkFromJson(dynamic json) {
    if (json is! Map) return null;
    return rust.Link(
      url: json['url'] as String,
      header: (json['header'] as Map<dynamic, dynamic>?)
          ?.cast<String, String>(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EntryOverrides &&
      title == other.title &&
      _listEquals(author, other.author) &&
      description == other.description &&
      _listEquals(genres, other.genres) &&
      cover == other.cover &&
      poster == other.poster;

  @override
  int get hashCode => Object.hash(
    title,
    author == null ? null : Object.hashAll(author!),
    description,
    genres == null ? null : Object.hashAll(genres!),
    cover,
    poster,
  );

  @override
  String toString() => 'EntryOverrides${toJson() ?? '{}'}';
}

bool _listEquals(List<String>? a, List<String>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
