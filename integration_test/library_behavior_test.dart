import 'package:dionysos/data/activity/activity.dart';
import 'package:dionysos/data/activity/episode.dart';
import 'package:dionysos/data/category.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/library/library_query.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:metis/metis.dart' as metis;
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

import 'utils/screenshot_harness.dart';

Future<Database> _openMemoryDb() async {
  final db = Database();
  await db.initDB(await metis.AdapterSurrealDB.connect('memory://'));
  register<Database>(db);
  return db;
}

rust.EntryDetailed _detail(String uid, String title, List<String> episodes) =>
    rust.EntryDetailed(
      id: rust.EntryId(uid: uid),
      url: 'https://example.com/$uid',
      titles: [title],
      mediaType: rust.MediaType.book,
      status: rust.ReleaseStatus.releasing,
      description: 'test',
      language: 'en',
      episodes: [
        for (final id in episodes)
          rust.Episode(
            id: rust.EpisodeId(uid: id),
            name: id,
            url: 'https://example.com/$id',
          ),
      ],
    );

EntrySaved _saved(
  String uid,
  String title, {
  List<String> episodes = const [],
  List<Category> categories = const [],
  Map<String, EpisodeData>? data,
}) {
  final detail = _detail(uid, title, episodes);
  return EntrySaved(
    entry: detail,
    original: detail,
    categories: [...categories],
    boundExtensionId: 'ext',
    episode: 0,
    savedSettings: EntrySavedSettings.defaultSettings(),
    extensionSettings: {},
    episodedata: data ?? {},
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(bootstrapScreenshots);

  Future<List<String>> search(Database db, String query) async => [
    for (final entry in await db.searchEntries(query, 0, 25).toList())
      entry.id.uid,
  ];

  testWidgets('library search finds partial words and split punctuation', (
    tester,
  ) async {
    final db = await _openMemoryDb();
    await db.addEntry(_saved('piece', 'One Piece'));
    await db.addEntry(_saved('fate', 'Fate/Zero Origins'));

    expect(await search(db, 'piec'), ['piece']);
    expect(await search(db, 'zero'), ['fate']);
    expect(await search(db, 'ORIG'), ['fate']);
    expect(await search(db, 'unrelated'), isEmpty);
  });

  testWidgets('deleting a category returns its entries to uncategorized', (
    tester,
  ) async {
    final db = await _openMemoryDb();
    final keep = Category.construct('keep', 0);
    final drop = Category.construct('drop', 1);
    await db.updateCategories([keep, drop]);
    await db.addEntry(_saved('only', 'Only Dropped', categories: [drop]));
    await db.addEntry(_saved('both', 'Both', categories: [keep, drop]));

    await db.removeCategory(drop);

    final uncategorized = await db
        .queryEntries(scope: const EntryScopeUncategorized(), page: 0)
        .toList();
    expect(uncategorized.map((e) => e.id.uid), ['only']);
    final kept = await db
        .queryEntries(scope: EntryScopeCategory(keep), page: 0)
        .toList();
    expect(kept.map((e) => e.id.uid), ['both']);
    expect(kept.single.categories.map((c) => c.name), ['keep']);
  });

  testWidgets('episode data follows the episode when the list reorders', (
    tester,
  ) async {
    final db = await _openMemoryDb();
    final entry = _saved(
      'order',
      'Reordered',
      episodes: ['a', 'b'],
      data: {'b': EpisodeData(bookmark: false, finished: true)},
    );
    await db.addEntry(entry);

    final json = entry.toJson();
    json['entry'] = _detail('order', 'Reordered', ['new', 'a', 'b']).toJson();
    final moved = await EntrySaved.fromJson(json);

    expect(moved.getEpisodeData(2).finished, isTrue);
    expect(moved.getEpisodeData(0).finished, isFalse);
    expect(moved.latestEpisode, 3);
  });

  testWidgets('pre-v6 positional episode data attaches by position', (
    tester,
  ) async {
    final entry = _saved('legacy', 'Legacy', episodes: ['a', 'b']);
    final json = entry.toJson();
    json['version'] = 5;
    json['episodedata'] = [
      EpisodeData.empty().toJson(),
      EpisodeData(bookmark: true, finished: false).toJson(),
    ];

    final parsed = await EntrySaved.fromJson(json);

    expect(parsed.episodedata.keys, ['b']);
    expect(parsed.getEpisodeData(1).bookmark, isTrue);
  });

  testWidgets('daily durations land on the local calendar day', (tester) async {
    final db = await _openMemoryDb();
    final local = DateTime.now().subtract(const Duration(days: 2));
    final lateNight = DateTime(local.year, local.month, local.day, 23, 50);
    final earlyMorning = DateTime(local.year, local.month, local.day, 0, 10);
    await db.addActivities([
      _activity(lateNight, 'late'),
      _activity(earlyMorning, 'early'),
    ]);

    final days = await db.getDailyActivityDurations();

    expect(days[DateTime.utc(local.year, local.month, local.day)], isNotNull);
    expect(days.length, 1);
  });
}

Activity _activity(DateTime time, String id) => EpisodeActivity(
  fromepisode: 0,
  toepisode: 0,
  entry: _saved(id, id),
  extensionid: 'ext',
  duration: const Duration(minutes: 5),
  time: time,
  id: id,
);
