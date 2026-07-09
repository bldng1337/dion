import 'package:dionysos/data/category.dart';
import 'package:dionysos/service/extension.dart';
import 'package:rdion_runtime/rdion_runtime.dart' show MediaType, ReleaseStatus;

sealed class EntryScope {
  const EntryScope();

  void writeCondition(List<String> conditions, Map<String, dynamic> vars);
}

class EntryScopeAll extends EntryScope {
  const EntryScopeAll();
  @override
  void writeCondition(List<String> conditions, Map<String, dynamic> vars) {
    // No restriction — every entry is in scope.
  }
}

class EntryScopeUncategorized extends EntryScope {
  const EntryScopeUncategorized();
  @override
  void writeCondition(List<String> conditions, Map<String, dynamic> vars) {
    conditions.add('count(categories) = 0');
  }
}

class EntryScopeCategory extends EntryScope {
  final Category category;
  const EntryScopeCategory(this.category);
  @override
  void writeCondition(List<String> conditions, Map<String, dynamic> vars) {
    conditions.add('categories CONTAINS \$scope_category');
    vars['scope_category'] = category.id;
  }

  @override
  bool operator ==(Object other) =>
      other is EntryScopeCategory && other.category == category;

  @override
  int get hashCode => category.hashCode;
}

enum LibrarySortKey {
  none,
  title,
  totalChapters,
  chaptersRead,
  chaptersUnread,
  rating;

  String get label => switch (this) {
    none => 'Default',
    title => 'Title',
    totalChapters => 'Total chapters',
    chaptersRead => 'Chapters read',
    chaptersUnread => 'Chapters unread',
    rating => 'Rating',
  };
}

class LibrarySort {
  final LibrarySortKey key;
  final bool descending;

  const LibrarySort({this.key = LibrarySortKey.none, this.descending = false});

  bool get isActive => key != LibrarySortKey.none;

  LibrarySort copyWith({LibrarySortKey? key, bool? descending}) => LibrarySort(
    key: key ?? this.key,
    descending: descending ?? this.descending,
  );

  LibrarySortProjection? toProjection() {
    final expr = _expression();
    if (expr == null) return null;
    final dir = descending ? 'DESC' : 'ASC';
    return LibrarySortProjection._(
      select: '$expr AS lib_sort',
      orderBy: 'ORDER BY lib_sort $dir',
    );
  }

  String? _expression() {
    switch (key) {
      case LibrarySortKey.none:
        return null;
      case LibrarySortKey.title:
        // titles is non-empty by construction (title = titles.first).
        return 'entry.titles[0]';
      case LibrarySortKey.totalChapters:
        return 'array::len(entry.episodes)';
      case LibrarySortKey.chaptersRead:
        return r'array::len(array::filter(episodedata, |$e| $e.finished = true))';
      case LibrarySortKey.chaptersUnread:
        return 'array::len(entry.episodes) - '
            r'array::len(array::filter(episodedata, |$e| $e.finished = true))';
      case LibrarySortKey.rating:
        return 'entry.rating';
    }
  }

  @override
  bool operator ==(Object other) =>
      other is LibrarySort &&
      other.key == key &&
      other.descending == descending;

  @override
  int get hashCode => Object.hash(key, descending);
}

class LibrarySortProjection {
  final String select;
  final String orderBy;
  const LibrarySortProjection._({required this.select, required this.orderBy});
}

class LibraryFilters {
  final Set<MediaType> mediaTypes;
  final Set<String> extensionIds;
  final Set<ReleaseStatus> statuses;
  final bool trackedOnly;

  const LibraryFilters({
    this.mediaTypes = const {},
    this.extensionIds = const {},
    this.statuses = const {},
    this.trackedOnly = false,
  });

  static const LibraryFilters empty = LibraryFilters();

  bool get isActive =>
      mediaTypes.isNotEmpty ||
      extensionIds.isNotEmpty ||
      statuses.isNotEmpty ||
      trackedOnly;

  LibraryFilters copyWith({
    Set<MediaType>? mediaTypes,
    Set<String>? extensionIds,
    Set<ReleaseStatus>? statuses,
    bool? trackedOnly,
  }) => LibraryFilters(
    mediaTypes: mediaTypes ?? this.mediaTypes,
    extensionIds: extensionIds ?? this.extensionIds,
    statuses: statuses ?? this.statuses,
    trackedOnly: trackedOnly ?? this.trackedOnly,
  );

  void writeConditions(List<String> conditions, Map<String, dynamic> vars) {
    if (mediaTypes.isNotEmpty) {
      // Stored as capitalized strings ("Video", "Audio", …).
      final values = mediaTypes.map((m) => "'${m.jsonValue}'").join(', ');
      conditions.add('entry.media_type IN [$values]');
    }
    if (extensionIds.isNotEmpty) {
      vars['flt_extensions'] = extensionIds.toList();
      conditions.add('extensionid IN \$flt_extensions');
    }
    if (statuses.isNotEmpty) {
      final values = statuses.map((s) => "'${s.jsonValue}'").join(', ');
      conditions.add('entry.status IN [$values]');
    }
    if (trackedOnly) {
      conditions.add('count(episodedata) > 0');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is LibraryFilters &&
      _setEq(other.mediaTypes, mediaTypes) &&
      _setEq(other.extensionIds, extensionIds) &&
      _setEq(other.statuses, statuses) &&
      other.trackedOnly == trackedOnly;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(mediaTypes),
    Object.hashAll(extensionIds),
    Object.hashAll(statuses),
    trackedOnly,
  );
}

bool _setEq<T>(Set<T> a, Set<T> b) => a.length == b.length && a.containsAll(b);

extension on MediaType {
  String get jsonValue => switch (this) {
    MediaType.video => 'Video',
    MediaType.audio => 'Audio',
    MediaType.book => 'Book',
    MediaType.comic => 'Comic',
    MediaType.unknown => 'Unknown',
  };
}

extension on ReleaseStatus {
  String get jsonValue => switch (this) {
    ReleaseStatus.releasing => 'Releasing',
    ReleaseStatus.complete => 'Complete',
    ReleaseStatus.unknown => 'Unknown',
  };
}
