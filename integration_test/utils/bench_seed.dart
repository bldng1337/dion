import 'dart:math';

import 'package:dionysos/data/category.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/service/database.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

const benchSourceIds = ['bench.source.a', 'bench.source.b'];

/// Creates and persists [entryCount] synthetic entries spread over
/// [benchSourceIds] and generated categories; every fifth entry stays
/// uncategorized so the "No Category" scope is populated too.
Future<void> seedBenchLibrary(
  Database db, {
  required int entryCount,
  int categoryCount = 6,
}) async {
  final categories = [
    for (var i = 0; i < categoryCount; i++) Category.construct('Bench $i', i),
  ];
  for (final category in categories) {
    await db.updateCategory(category);
  }
  for (var i = 0; i < entryCount; i++) {
    final entry = benchEntry(
      i,
      categories: i % 5 == 0 ? [] : [categories[i % categoryCount]],
    );
    await db.adapter.save(entry);
  }
}

EntrySaved benchEntry(
  int i, {
  required List<Category> categories,
  rust.Link? cover,
  rust.Link? poster,
}) {
  final mediaType = switch (i % 4) {
    0 => rust.MediaType.book,
    1 => rust.MediaType.comic,
    2 => rust.MediaType.video,
    _ => rust.MediaType.audio,
  };
  final status = switch (i % 3) {
    0 => rust.ReleaseStatus.releasing,
    1 => rust.ReleaseStatus.complete,
    _ => rust.ReleaseStatus.unknown,
  };
  final episodeCount = 10 + i % 20;
  final detailed = rust.EntryDetailed(
    id: rust.EntryId(uid: 'bench-$i'),
    url: 'https://bench.example/entry/$i',
    cover: cover,
    poster: poster,
    titles: ['Bench Entry ${i.toString().padLeft(5, '0')} ${_titleWord(i)}'],
    author: ['Author ${i % 37}'],
    mediaType: mediaType,
    status: status,
    description:
        'Synthetic benchmark entry $i. '
        'The description is padded so row sizes resemble real entries with a '
        'few hundred bytes of metadata per record. '
        'Seed ${i * 2654435761 % 99991}.',
    language: 'en',
    episodes: [
      for (var e = 0; e < episodeCount; e++)
        rust.Episode(
          id: rust.EpisodeId(uid: 'bench-$i-ep-$e'),
          name: 'Episode ${e + 1}',
          url: 'https://bench.example/entry/$i/episode/$e',
        ),
    ],
    genres: ['bench', mediaType.name],
    rating: 3 + (i % 20) / 10,
    views: ((i * 137) % 100000).toDouble(),
    length: 100 + i % 900,
  );
  final readCount = i % episodeCount;
  return EntrySaved(
    entry: detailed,
    original: detailed,
    categories: categories,
    episodedata: {
      for (var e = 0; e < readCount; e++)
        'bench-$i-ep-$e': EpisodeData(bookmark: e % 7 == 0, finished: true),
    },
    boundExtensionId: benchSourceIds[i % benchSourceIds.length],
    episode: max(0, readCount - 1),
    savedSettings: EntrySavedSettings.defaultSettings(),
    extensionSettings: const {},
  );
}

const _titleWords = [
  'Chronicles',
  'Protocol',
  'Symphony',
  'Voyage',
  'Codex',
  'Requiem',
  'Garden',
  'Circuit',
  'Harbor',
  'Mirage',
];

String _titleWord(int i) => _titleWords[i % _titleWords.length];
