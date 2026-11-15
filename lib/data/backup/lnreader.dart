import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:dionysos/data/backup/foreign.dart';
import 'package:rdion_runtime/rdion_runtime.dart' show MediaType, ReleaseStatus;

const _versionFile = 'Version.json';
const _categoryFile = 'Category.json';
const _novelDir = 'NovelAndChapters/';
// Drive and self-host backups keep the data in a nested archive.
const _dataArchive = 'data.zip';

/// The ids LNReader seeds its own "Default" and "Local" categories with.
const _systemCategoryIds = {1, 2};

bool isLnReaderBackup(Archive archive) =>
    archive.findFile(_versionFile) != null ||
    archive.findFile(_dataArchive) != null ||
    archive.files.any((file) => file.name.startsWith(_novelDir));

/// Parses an LNReader backup archive.
ForeignBackup parseLnReaderBackup(Archive archive) {
  if (!archive.files.any((file) => file.name.startsWith(_novelDir))) {
    final nested = archive.findFile(_dataArchive);
    if (nested != null) {
      return parseLnReaderBackup(ZipDecoder().decodeBytes(nested.content));
    }
  }

  final categoriesById = <int, ({String name, int sort})>{};
  final categoryFile = archive.findFile(_categoryFile);
  final novelCategories = <int, List<String>>{};
  if (categoryFile != null) {
    for (final raw in _decode(categoryFile) as List) {
      final category = raw as Map<String, dynamic>;
      final id = _int(category['id']);
      final name = (category['name'] as String? ?? '').trim();
      if (id == null || _systemCategoryIds.contains(id) || name.isEmpty) {
        continue;
      }
      categoriesById[id] = (name: name, sort: _int(category['sort']) ?? id);
      for (final novelId in category['novelIds'] as List? ?? const []) {
        (novelCategories[_int(novelId) ?? -1] ??= []).add(name);
      }
    }
  }

  final entries = <ForeignEntry>[];
  final skipped = <String>[];
  for (final file in archive.files) {
    if (!file.isFile ||
        !file.name.startsWith(_novelDir) ||
        !file.name.endsWith('.json')) {
      continue;
    }
    final novel = _decode(file) as Map<String, dynamic>;
    if (!_bool(novel['inLibrary'])) continue;
    final name = novel['name'] as String? ?? '';
    final pluginId = novel['pluginId'] as String? ?? '';
    if (_bool(novel['isLocal']) || pluginId == 'local') {
      skipped.add('$name: local novels have no source to restore from');
      continue;
    }
    entries.add(
      _entry(novel, pluginId, novelCategories[_int(novel['id'])] ?? const []),
    );
  }

  final sortedCategories = categoriesById.values.toList()
    ..sort((a, b) => a.sort.compareTo(b.sort));
  return ForeignBackup(
    app: 'LNReader',
    categories: [
      for (final (index, category) in sortedCategories.indexed)
        ForeignCategory(category.name, index),
    ],
    entries: entries,
    skipped: skipped,
  );
}

ForeignEntry _entry(
  Map<String, dynamic> novel,
  String pluginId,
  List<String> categories,
) {
  final chapters = [
    for (final raw in novel['chapters'] as List? ?? const [])
      raw as Map<String, dynamic>,
  ]..sort(_chapterOrder);
  final cover = novel['cover'] as String?;
  return ForeignEntry(
    source: LnReaderSource(pluginId),
    url: novel['path'] as String? ?? '',
    title: novel['name'] as String? ?? '',
    mediaType: MediaType.book,
    authors: {
      for (final key in const ['author', 'artist'])
        ...?(novel[key] as String?)
            ?.split(',')
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty),
    }.toList(),
    description: novel['summary'] as String?,
    genres: [
      ...?(novel['genres'] as String?)
          ?.split(',')
          .map((genre) => genre.trim())
          .where((genre) => genre.isNotEmpty),
    ],
    status: switch ((novel['status'] as String?)?.toLowerCase()) {
      'ongoing' => ReleaseStatus.releasing,
      'completed' || 'publishing finished' => ReleaseStatus.complete,
      _ => ReleaseStatus.unknown,
    },
    // Anything else points into LNReader's own storage.
    cover: cover != null && cover.startsWith('http') ? cover : null,
    categories: categories,
    chapters: [
      for (final chapter in chapters)
        ForeignChapter(
          url: chapter['path'] as String? ?? '',
          name: chapter['name'] as String? ?? '',
          description: chapter['scanlator'] as String?,
          uploaded: _date(chapter['releaseTime']),
          // `unread` defaults to true in LNReader's schema.
          finished: !_bool(chapter['unread'] ?? true),
          bookmark: _bool(chapter['bookmark']),
          // LNReader stores a scroll percentage; dion tracks paragraphs.
        ),
    ],
    history: [
      for (final chapter in chapters)
        if (_date(chapter['readTime']) case final time?)
          ForeignHistory(
            chapter['path'] as String? ?? '',
            time,
            Duration(milliseconds: _int(chapter['timeSpent']) ?? 0),
          ),
    ],
  );
}

/// LNReader lists multi-page novels page by page, each in source order.
int _chapterOrder(Map<String, dynamic> a, Map<String, dynamic> b) {
  final page = (int.tryParse('${a['page']}') ?? 0).compareTo(
    int.tryParse('${b['page']}') ?? 0,
  );
  if (page != 0) return page;
  final position = (_int(a['position']) ?? 0).compareTo(
    _int(b['position']) ?? 0,
  );
  if (position != 0) return position;
  return (_int(a['id']) ?? 0).compareTo(_int(b['id']) ?? 0);
}

dynamic _decode(ArchiveFile file) =>
    json.decode(utf8.decode(file.content, allowMalformed: true));

/// Older exports store booleans as 0/1.
bool _bool(dynamic value) => switch (value) {
  final bool b => b,
  final num n => n != 0,
  'true' || '1' => true,
  _ => false,
};

int? _int(dynamic value) => switch (value) {
  final int i => i,
  final num n => n.toInt(),
  final String s => int.tryParse(s),
  _ => null,
};

DateTime? _date(dynamic value) {
  if (value is num) return dateFromEpochMillis(value.toInt());
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value) ?? dateFromEpochMillis(int.tryParse(value));
}
