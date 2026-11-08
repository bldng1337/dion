import 'package:dionysos/data/category.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/library/library_query.dart';
import 'package:dionysos/data/versioning.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:metis/metis.dart' as metis;
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

import 'utils/screenshot_harness.dart';

const _episodes = ['https://x.y/ep/1', 'https://x.y/ep/2', 'https://x.y/ep/3'];

Future<Database> _openDb() async {
  final db = Database();
  await db.initDB(await metis.AdapterSurrealDB.connect('memory://'));
  return db;
}

rust.EntryDetailed _detail({String description = 'original'}) =>
    rust.EntryDetailed(
      id: const rust.EntryId(uid: 'series'),
      url: 'https://x.y',
      titles: ['Series'],
      mediaType: rust.MediaType.book,
      status: rust.ReleaseStatus.releasing,
      description: description,
      language: 'en',
      episodes: [
        for (final id in _episodes)
          rust.Episode(
            id: rust.EpisodeId(uid: id),
            name: id,
            url: id,
          ),
      ],
    );

EntrySaved _entry({List<Category> categories = const []}) {
  final detail = _detail();
  return EntrySaved(
    entry: detail,
    original: detail,
    categories: [...categories],
    boundExtensionId: 'ext',
    episode: 0,
    savedSettings: EntrySavedSettings.defaultSettings(),
    extensionSettings: {},
    episodedata: {},
  );
}

metis.CrdtAdapter _crdt(Database db) =>
    db.db.getAdapter<metis.CrdtAdapter>();

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 150));

/// Reads the stored row into a new instance, past the identity cache.
Future<EntrySaved> _stored(Database db, EntrySaved entry) async =>
    EntrySaved.fromJson(
      Map<String, dynamic>.from(await db.db.select(entry.dbId) as Map),
    );

/// Two devices holding the same entry, each with its own live instance.
Future<(Database, EntrySaved, Database, EntrySaved)> _pair() async {
  final a = await _openDb();
  final b = await _openDb();
  register<Database>(a);
  final entryA = _entry();
  await a.addEntry(entryA);
  await _settle();
  await _crdt(a).sync(_crdt(b).syncRepo);
  await _settle();
  final entryB = (await b.isSaved(entryA))!;
  return (a, entryA, b, entryB);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(bootstrapScreenshots);

  testWidgets('offline reading on two devices keeps everything', (
    tester,
  ) async {
    final (a, entryA, b, entryB) = await _pair();

    entryA.getEpisodeDataById(_episodes[0]).finished = true;
    entryA.getEpisodeDataById(_episodes[2]).bookmark = true;
    await a.updateEntry(entryA);
    await _settle();
    entryB.getEpisodeDataById(_episodes[1]).finished = true;
    entryB.getEpisodeDataById(_episodes[2]).progress = '42';
    await b.updateEntry(entryB);
    await _settle();

    await _crdt(a).sync(_crdt(b).syncRepo);

    for (final db in [a, b]) {
      final row = await _stored(db, entryA);
      expect(row.getEpisodeDataById(_episodes[0]).finished, isTrue);
      expect(row.getEpisodeDataById(_episodes[1]).finished, isTrue);
      expect(row.getEpisodeDataById(_episodes[2]).bookmark, isTrue);
      expect(row.getEpisodeDataById(_episodes[2]).progress, '42');
      final raw = await db.db.select(entryA.dbId) as Map;
      expect(raw['sort_chapters_read'], 2);
      expect(raw['sort_chapters_unread'], 1);
    }
  });

  testWidgets('a refresh does not wipe notes, ratings or bookmarks', (
    tester,
  ) async {
    final (a, entryA, b, entryB) = await _pair();

    entryA
      ..note = 'mine'
      ..userRating = 4.5;
    entryA.getEpisodeDataById(_episodes[0]).bookmark = true;
    await a.updateEntry(entryA);
    await _settle();
    entryB
      ..entry = _detail(description: 'refreshed')
      ..original = _detail(description: 'refreshed')
      ..lastRefreshed = DateTime.now();
    await b.updateEntry(entryB);
    await _settle();

    await _crdt(a).sync(_crdt(b).syncRepo);

    for (final db in [a, b]) {
      final row = await _stored(db, entryA);
      expect(row.note, 'mine');
      expect(row.userRating, 4.5);
      expect(row.getEpisodeDataById(_episodes[0]).bookmark, isTrue);
      expect(row.description, 'refreshed');
    }
  });

  testWidgets('categories added on both devices are both kept', (tester) async {
    final (a, entryA, b, entryB) = await _pair();
    final one = Category.construct('one', 0);
    final two = Category.construct('two', 1);
    await a.updateCategories([one, two]);
    await b.updateCategories([one, two]);

    entryA.categories = [one];
    await a.updateEntry(entryA);
    await _settle();
    entryB.categories = [two];
    await b.updateEntry(entryB);
    await _settle();
    await _crdt(a).sync(_crdt(b).syncRepo);

    final raw = await a.db.select(entryA.dbId) as Map;
    expect(raw['categories'], unorderedEquals([one.id, two.id]));
  });

  testWidgets('a removed entry stays removed despite a later refresh', (
    tester,
  ) async {
    final (a, entryA, b, entryB) = await _pair();
    await a.removeEntry(entryA);
    await _settle();
    entryB.lastRefreshed = DateTime.now();
    await b.updateEntry(entryB);
    await _settle();

    await _crdt(a).sync(_crdt(b).syncRepo);

    expect(await a.db.select(entryA.dbId), isNull);
    expect(await b.db.select(entryA.dbId), isNull);
  });

  testWidgets('an open reader absorbs a sync and keeps unsaved progress', (
    tester,
  ) async {
    final (a, entryA, b, entryB) = await _pair();
    entryA.getEpisodeDataById(_episodes[0]).progress = '50'; // not saved yet

    entryB.getEpisodeDataById(_episodes[1]).bookmark = true;
    await b.updateEntry(entryB);
    await _settle();
    await _crdt(a).sync(_crdt(b).syncRepo);
    await _settle();

    expect(entryA.getEpisodeDataById(_episodes[1]).bookmark, isTrue);
    expect(entryA.getEpisodeDataById(_episodes[0]).progress, '50');

    await a.updateEntry(entryA);
    await _settle();
    await _crdt(a).sync(_crdt(b).syncRepo);

    final row = await _stored(b, entryA);
    expect(row.getEpisodeDataById(_episodes[0]).progress, '50');
    expect(row.getEpisodeDataById(_episodes[1]).bookmark, isTrue);
  });

  testWidgets('the v6 migration rewrites episode data and keeps timestamps', (
    tester,
  ) async {
    final db = await _openDb();
    register<Database>(db);
    final entry = _entry();
    entry.getEpisodeDataById(_episodes[1]).bookmark = true;
    await db.addEntry(entry);
    await _settle();

    final legacy = entry.toJson()
      ..['version'] = 6
      ..['episodedata'] = [
        {
          ...EpisodeData(bookmark: true, finished: false).toJson(),
          'episode': _episodes[1],
        },
      ];
    await _crdt(db).runUnstamped(() => db.db.upsert(entry.dbId, legacy));
    final before = await _crdt(db).syncRepo.getSyncData(entry.dbId);
    await db.db.upsert(const metis.DBRecord('_version', 'app'), {'version': 5});

    final reopened = Database();
    await reopened.initDB(db.db);
    register<Database>(reopened);
    await _settle();

    final raw = await db.db.select(entry.dbId) as Map;
    expect(raw['version'], entrySerializeVersion.current);
    expect(raw['episodedata'], isA<Map<dynamic, dynamic>>());
    expect(raw['episodedata'][_episodes[1]]['bookmark'], isTrue);
    final after = await _crdt(db).syncRepo.getSyncData(entry.dbId);
    expect(after!.hlc.toString(), before!.hlc.toString());
  });

  testWidgets('derived columns match on saved and recomputed rows', (
    tester,
  ) async {
    final entry = _entry();
    entry.getEpisodeDataById(_episodes[0]).finished = true;
    final json = entry.toJson();
    expect(json['sort_title'], 'Series');
    expect(json['sort_total_chapters'], 3);
    expect(json['sort_chapters_read'], 1);
    expect(json['sort_chapters_unread'], 2);
    expect(json['search_text'], 'Series');
    expect(recomputeEntryColumns(json), json);
  });

  testWidgets('the tracked filter sees episode data stored as an object', (
    tester,
  ) async {
    final db = await _openDb();
    register<Database>(db);
    const tracked = LibraryFilters(trackedOnly: true);
    final entry = _entry();
    await db.addEntry(entry);
    expect(await db.countEntries(filters: tracked), 0);
    entry.getEpisodeDataById(_episodes[0]).finished = true;
    await db.updateEntry(entry);
    expect(await db.countEntries(filters: tracked), 1);
  });
}
