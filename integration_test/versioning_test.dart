import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dionysos/data/Category.dart';
import 'package:dionysos/data/entry/entry.dart' as entrydata;
import 'package:dionysos/data/entry/entry_detailed.dart' as entrydata;
import 'package:dionysos/data/entry/entry_saved.dart' as entrydata;
import 'package:dionysos/data/versioning.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/views/settings/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metis/metis.dart' as metis;
import 'package:metis/metis.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rdion_runtime/rdion_runtime.dart';

import 'utils/mock.dart';

class MockExtension extends Mock implements Extension {}

entrydata.Entry getEntry(Extension ext) => entrydata.EntryImpl(
  const Entry(
    id: 'id',
    url: 'url',
    title: 'title',
    mediaType: MediaType.comic,
    cover: 'cover',
    coverHeader: {'header': 'header'},
    author: ['author'],
    rating: 1.0,
    views: 1,
    length: 1,
  ),
  ext,
);

entrydata.EntryDetailed getEntryDetailed(Extension ext) =>
    entrydata.EntryDetailedImpl(
      const EntryDetailed(
        id: 'test',
        url: 'url',
        title: 'title',
        coverHeader: {'header': 'header'},
        author: ['author'],
        ui: CustomUI.text(text: 'text'),
        mediaType: MediaType.audio,
        status: ReleaseStatus.releasing,
        description: 'description',
        language: 'language',
        episodes: [
          Episode(
            id: 'id',
            name: 'name',
            url: 'url',
            cover: 'cover',
            coverHeader: {'header': 'header'},
            timestamp: 'timestamp',
          ),
        ],
      ),
      ext,
    );

entrydata.EntrySaved getEntrySaved(Extension ext) => entrydata.EntrySaved(
  settings: entrydata.EntrySavedSettings.defaultSettings(),
  entry: const EntryDetailed(
    id: 'test',
    url: 'url',
    title: 'title',
    coverHeader: {'header': 'header'},
    author: ['author'],
    ui: CustomUI.text(text: 'text'),
    mediaType: MediaType.audio,
    status: ReleaseStatus.releasing,
    description: 'description',
    language: 'language',
    episodes: [
      Episode(
        id: 'id',
        name: 'name',
        url: 'url',
        cover: 'cover',
        coverHeader: {'header': 'header'},
        timestamp: 'timestamp',
      ),
    ],
  ),
  extension: ext,
  episodedata: [entrydata.EpisodeData.empty()],
  episode: 0,
  categories: [const Category('test', DBRecord('category', 'test'))],
);

void main() {
  group('Versioning', () {
    setUpAll(() {
      registerFallbackValue(getEntryDetailed(MockExtension()));
      registerFallbackValue(getEntrySaved(MockExtension()));
    });
    group('Entry', () {
      test('Write current serialization', () async {
        final ext = MockExtension();
        when(() => ext.id).thenReturn('test');
        (Directory('data')
                .sub('version')
                .sub('entry')
                .getFile('${entrySerializeVersion.current}.json')
              ..createSync(recursive: true))
            .writeAsStringSync(
              jsonEncode({
                'version': entrySerializeVersion.current,
                'entry': getEntry(ext).toEntryJson(),
                'entrysaved': getEntrySaved(ext).toJson(),
              }),
            );
      }, tags: ['writing']);

      test('Deserialize for every version', () async {
        final mockdb = await mockDatabase();
        final srcextension = await mockSourceExtension();
        final mockext = MockExtension();
        when(() => srcextension.getExtension(any())).thenReturn(mockext);
        when(
          () => mockdb.getCategoriesbyId([const DBRecord('category', 'test')]),
        ).thenAnswer(
          (_) => Future.value([
            const Category('test', DBRecord('category', 'test')),
          ]),
        );

        for (final file in Directory(
          '',
        ).sub('data').sub('version').sub('entry').listSync()) {
          final json = jsonDecode(File(file.path).readAsStringSync());
          expect(
            entrydata.Entry.fromJson(json['entry'] as Map<String, dynamic>),
            isA<entrydata.EntryImpl>(),
          );
          expect(
            await entrydata.EntrySaved.fromJson(
              json['entrysaved'] as Map<String, dynamic>,
            ),
            isA<entrydata.EntrySaved>(),
          );
        }
      });
    });

    group('Database', () {
      setUpAll(() async => await metis.RustLib.init());
      test('Write current DB version', () async {
        final db = Database();
        final path =
            (Directory('data').sub('version').sub('database')
                  ..createSync(recursive: true))
                .sub('$dbVersion')
                .absolute
                .path;
        await db.initDB(await AdapterSurrealDB.newFile(path));
        final ext = MockExtension();
        when(() => ext.id).thenReturn('test');
        final saved = getEntrySaved(ext);
        for (final cat in saved.categories) {
          await db.updateCategory(cat);
        }
        await db.updateEntry(saved);
        db.db.dispose();
        await Future.delayed(const Duration(milliseconds: 100));
      }, tags: ['writing']);

      test('Read all DB versions', () async {
        final srcextension = await mockSourceExtension();
        final mockext = MockExtension();
        when(() => srcextension.getExtension(any())).thenReturn(mockext);
        for (final file in Directory('data/version/database').listSync()) {
          final db = Database();
          await db.initDB(await AdapterSurrealDB.newFile(file.path));
          db.getEntries(0, 10);
          db.db.dispose();
        }
      });
    });

    group('Backup', () {
      test('Create Backup', () async {
        final mockdb = await mockDatabase();
        when(
          () => mockdb.getCategoriesbyId([const DBRecord('category', 'test')]),
        ).thenAnswer(
          (_) => Future.value([
            const Category('test', DBRecord('category', 'test')),
          ]),
        );
        final mockext = MockExtension();
        when(
          () => mockdb.getEntries(any(), any()),
        ).thenAnswer((_) => Stream.fromIterable([getEntrySaved(mockext)]));

        when(() => mockext.id).thenReturn('test');
        final archive = await createBackup();
        final file =
            (Directory('data').sub('version').sub('backup')
                  ..createSync(recursive: true))
                .getFile('$archiveVersion.dpkg');
        await file.create(recursive: true);
        await file.writeAsBytes(ZipEncoder().encodeBytes(archive));
      }, tags: ['writing']);
      test('Apply Backup', () async {
        final mockdb = await mockDatabase();
        when(
          () => mockdb.getCategoriesbyId([const DBRecord('category', 'test')]),
        ).thenAnswer(
          (_) => Future.value([
            const Category('test', DBRecord('category', 'test')),
          ]),
        );
        when(() => mockdb.updateEntry(any())).thenAnswer((args) async {
          final data = args.positionalArguments[0];
          expect(data, isNotNull);
        });
        final mockext = MockExtension();
        when(
          () => mockdb.getEntries(any(), any()),
        ).thenAnswer((_) => Stream.fromIterable([getEntrySaved(mockext)]));

        when(() => mockext.id).thenReturn('test');
        for (final file in Directory('data/version/backup').listSync()) {
          if (file is! File) {
            continue;
          }
          final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
          await applyBackup(archive);
        }
      });
    });
  });
}
