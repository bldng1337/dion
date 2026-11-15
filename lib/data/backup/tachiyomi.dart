import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dionysos/data/backup/foreign.dart';
import 'package:dionysos/data/backup/protobuf.dart';
import 'package:rdion_runtime/rdion_runtime.dart' show MediaType, ReleaseStatus;

// Field numbers follow the kotlinx `@ProtoNumber`s of the backup models in
// eu.kanade.tachiyomi.data.backup.models of Mihon, Aniyomi and Tsundoku.
abstract final class _Backup {
  static const manga = 1;
  static const categories = 2;
  static const sources = 101;
  static const aniyomiMarker = 500;
  // Aniyomi moved its anime lists from 3/4/103 to 501..503; both layouts
  // exist in the wild and never overlap.
  static const animeLegacy = 3;
  static const animeCategoriesLegacy = 4;
  static const animeSourcesLegacy = 103;
  static const anime = 501;
  static const animeCategories = 502;
  static const animeSources = 503;
}

abstract final class _Manga {
  static const source = 1;
  static const url = 2;
  static const title = 3;
  static const artist = 4;
  static const author = 5;
  static const description = 6;
  static const genre = 7;
  static const status = 8;
  static const thumbnail = 9;
  static const chapters = 16;
  static const categories = 17;
  static const favorite = 100;
  static const history = 104;
  static const notes = 110;
  static const animeBackground = 500;
  static const tsundokuIsNovel = 8000;
  static const tsundokuAltTitles = 8001;
}

abstract final class _Chapter {
  static const url = 1;
  static const name = 2;
  static const scanlator = 3;
  static const read = 4;
  static const bookmark = 5;
  static const lastPageRead = 6;
  static const dateUpload = 8;
  static const sourceOrder = 10;
  static const animeSummary = 502;
  static const animePreview = 503;
}

bool isGzip(Uint8List bytes) =>
    bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;

/// Parses a Mihon, Aniyomi or Tsundoku backup (`.tachibk`, `.proto.gz`),
/// gzipped or not.
ForeignBackup parseTachiyomiBackup(Uint8List bytes) {
  final raw = isGzip(bytes)
      ? Uint8List.fromList(const GZipDecoder().decodeBytes(bytes))
      : bytes;
  final backup = ProtoMessage.decode(raw);

  final sourceNames = <int, String>{
    for (final field in const [
      _Backup.sources,
      _Backup.animeSourcesLegacy,
      _Backup.animeSources,
    ])
      for (final source in backup.messages(field))
        source.int64Or(2, 0): source.string(1) ?? '',
  };

  final mangaCategories = _categories(backup.messages(_Backup.categories));
  final animeCategories = _categories([
    ...backup.messages(_Backup.animeCategoriesLegacy),
    ...backup.messages(_Backup.animeCategories),
  ]);

  final manga = backup.messages(_Backup.manga);
  final anime = [
    ...backup.messages(_Backup.animeLegacy),
    ...backup.messages(_Backup.anime),
  ];

  final entries = <ForeignEntry>[];
  var tsundoku = false;
  for (final item in manga) {
    if (!(item.boolean(_Manga.favorite) ?? true)) continue;
    final isNovel = item.boolean(_Manga.tsundokuIsNovel) ?? false;
    tsundoku |=
        item.has(_Manga.tsundokuIsNovel) || item.has(_Manga.tsundokuAltTitles);
    entries.add(
      _entry(
        item,
        isNovel ? MediaType.book : MediaType.comic,
        sourceNames,
        mangaCategories,
      ),
    );
  }
  for (final item in anime) {
    if (!(item.boolean(_Manga.favorite) ?? true)) continue;
    entries.add(_entry(item, MediaType.video, sourceNames, animeCategories));
  }

  final categoryOrder = <String, int>{};
  for (final category in [
    ...mangaCategories.values,
    ...animeCategories.values,
  ]) {
    categoryOrder.putIfAbsent(category.name, () => categoryOrder.length);
  }

  return ForeignBackup(
    app: anime.isNotEmpty || backup.has(_Backup.aniyomiMarker)
        ? 'Aniyomi'
        : tsundoku
        ? 'Tsundoku'
        : 'Mihon',
    categories: [
      for (final MapEntry(:key, :value) in categoryOrder.entries)
        ForeignCategory(key, value),
    ],
    entries: entries,
  );
}

/// Entries reference categories by their `order`, not by id.
Map<int, ForeignCategory> _categories(List<ProtoMessage> categories) {
  final sorted = [
    for (final category in categories)
      ForeignCategory(category.string(1) ?? '', category.int64Or(2, 0)),
  ]..sort((a, b) => a.order.compareTo(b.order));
  return {
    for (final category in sorted)
      if (category.name.isNotEmpty) category.order: category,
  };
}

ForeignEntry _entry(
  ProtoMessage item,
  MediaType mediaType,
  Map<int, String> sourceNames,
  Map<int, ForeignCategory> categories,
) {
  final sourceId = item.int64Or(_Manga.source, 0);
  final indexed = item.messages(_Manga.chapters).indexed.toList()
    // sourceOrder 0 is the top of the source's list, i.e. the newest chapter.
    ..sort((a, b) {
      final order = b.$2
          .int64Or(_Chapter.sourceOrder, 0)
          .compareTo(a.$2.int64Or(_Chapter.sourceOrder, 0));
      return order != 0 ? order : b.$1.compareTo(a.$1);
    });
  final authors = {
    for (final field in const [_Manga.author, _Manga.artist])
      ...?item
          .string(field)
          ?.split(',')
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty),
  };
  final note = item.string(_Manga.notes);
  return ForeignEntry(
    source: TachiyomiSource(sourceId, sourceNames[sourceId]),
    url: item.string(_Manga.url) ?? '',
    title: item.string(_Manga.title) ?? '',
    altTitles: item.strings(_Manga.tsundokuAltTitles),
    mediaType: mediaType,
    authors: authors.toList(),
    description: item.string(_Manga.description),
    genres: [
      for (final genre in item.strings(_Manga.genre))
        ...genre.split(',').map((g) => g.trim()).where((g) => g.isNotEmpty),
    ],
    status: switch (item.int64(_Manga.status)) {
      1 => ReleaseStatus.releasing,
      2 || 4 => ReleaseStatus.complete,
      _ => ReleaseStatus.unknown,
    },
    cover: item.string(_Manga.thumbnail),
    poster: mediaType == MediaType.video
        ? item.string(_Manga.animeBackground)
        : null,
    note: note == null || note.isEmpty ? null : note,
    chapters: [
      for (final (_, chapter) in indexed) _chapter(chapter, mediaType),
    ],
    categories: [
      for (final order in item.int64s(_Manga.categories))
        if (categories[order] case final category?) category.name,
    ],
    history: [
      for (final history in item.messages(_Manga.history))
        if (dateFromEpochMillis(history.int64(2)) case final time?)
          ForeignHistory(
            history.string(1) ?? '',
            time,
            Duration(milliseconds: history.int64Or(3, 0)),
          ),
    ],
  );
}

ForeignChapter _chapter(ProtoMessage chapter, MediaType mediaType) {
  final finished = chapter.boolean(_Chapter.read) ?? false;
  final position = chapter.int64Or(_Chapter.lastPageRead, 0);
  final scanlator = chapter.string(_Chapter.scanlator);
  final summary = chapter.string(_Chapter.animeSummary);
  return ForeignChapter(
    url: chapter.string(_Chapter.url) ?? '',
    name: chapter.string(_Chapter.name) ?? '',
    description: scanlator ?? summary,
    cover: chapter.string(_Chapter.animePreview),
    uploaded: dateFromEpochMillis(chapter.int64(_Chapter.dateUpload)),
    finished: finished,
    bookmark: chapter.boolean(_Chapter.bookmark) ?? false,
    progress: finished || position <= 0
        ? null
        : switch (mediaType) {
            // Mihon stores the 0-based page index, like dion's image reader.
            MediaType.comic => '$position',
            // Aniyomi's lastSecondSeen is in milliseconds despite its name.
            MediaType.video => '0:$position',
            // Tsundoku stores a scroll percentage; dion tracks paragraphs.
            _ => null,
          },
  );
}
