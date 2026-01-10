import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dionysos/data/Category.dart';
import 'package:dionysos/data/entry/entry.dart' as entrydata;
import 'package:dionysos/data/entry/entry_saved.dart' as entrydata;
import 'package:dionysos/data/versioning.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/views/settings/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metis/metis.dart' as metis;
import 'package:metis/metis.dart' hide Action;
import 'package:mocktail/mocktail.dart';
import 'package:rdion_runtime/rdion_runtime.dart' hide Action;

import 'utils/mock.dart';

const Map<String, entrydata.Entry> emptyEntryList = {
  'minimal': entrydata.EntryImpl(
    Entry(
      id: EntryId(uid: 'idasd'),
      url: 'url',
      title: 'title',
      mediaType: MediaType.comic,
      cover: Link(url: 'cover'),
      author: ['author'],
    ),
    'test',
  ),
  'comprehensive': entrydata.EntryImpl(
    Entry(
      id: EntryId(uid: 'id', iddata: 'sadasd'),
      url: 'url',
      title: 'title',
      mediaType: MediaType.book,
      cover: Link(url: 'cover', header: {'header': 'header'}),
      author: ['author', 'author2'],
      rating: 1.0,
      views: 1,
      length: 1,
    ),
    'test',
  ),
};

const Map<String, EntryDetailed> emptyEntryDetailedList = {
  'minimal': EntryDetailed(
    id: EntryId(uid: 'test'),
    url: 'url',
    titles: ['title'],
    mediaType: MediaType.audio,
    status: ReleaseStatus.releasing,
    description: 'description',
    language: 'language',
    episodes: [
      Episode(
        id: EpisodeId(uid: 'id'),
        name: 'name',
        url: 'url',
        cover: Link(url: 'cover', header: {'header': 'header'}),
        timestamp: 'timestamp',
      ),
    ],
  ),
  'comprehensive': EntryDetailed(
    id: EntryId(uid: 'test', iddata: 'asdasd'),
    url: 'url',
    titles: ['title', 'title2'],
    author: ['author', 'author2'],
    ui: CustomUI.column(
      children: [
        CustomUI.text(text: 'text'),
        CustomUI.button(
          label: 'button',
          onClick: UIAction.action(action: Action.openBrowser(url: 'url')),
        ),
        CustomUI.card(
          image: Link(url: 'image'),
          bottom: CustomUI.text(text: 'bottom'),
          top: CustomUI.text(text: 'top'),
        ),
        CustomUI.text(text: 'column text'),
        CustomUI.image(image: Link(url: 'image'), width: 100, height: 200),
        CustomUI.link(link: 'https://example.com', label: 'example'),
        CustomUI.timeStamp(
          timestamp: '2020-01-01T00:00:00Z',
          display: TimestampType.relative,
        ),
        CustomUI.entryCard(
          entry: Entry(
            id: EntryId(uid: 'entryCard'),
            url: 'url',
            title: 'Entry Card',
            mediaType: MediaType.book,
            cover: Link(url: 'cover'),
          ),
        ),
        CustomUI.card(
          image: Link(url: 'cardImage'),
          top: CustomUI.text(text: 'card top'),
          bottom: CustomUI.text(text: 'card bottom'),
        ),
        CustomUI.feed(event: 'feedEvent', data: 'feedData'),
        CustomUI.button(
          label: 'Open Browser',
          onClick: UIAction.action(
            action: Action.openBrowser(url: 'https://example.com'),
          ),
        ),
        CustomUI.button(
          label: 'Trigger Event',
          onClick: UIAction.action(
            action: Action.triggerEvent(event: 'evt', data: 'data'),
          ),
        ),
        CustomUI.button(
          label: 'Nav',
          onClick: UIAction.action(
            action: Action.nav(
              title: 'Nav Title',
              content: CustomUI.text(text: 'nav content'),
            ),
          ),
        ),
        CustomUI.button(
          label: 'Popup',
          onClick: UIAction.action(
            action: Action.popup(
              title: 'Popup Title',
              content: CustomUI.text(text: 'popup content'),
              actions: [],
            ),
          ),
        ),
        CustomUI.inlineSetting(
          settingId: 'setting_inline',
          settingKind: SettingKind.extension_,
          onCommit: UIAction.swapContent(
            targetid: 'target',
            event: 'committed',
            data: 'true',
            placeholder: CustomUI.text(text: 'saving...'),
          ),
        ),
        CustomUI.slot(
          id: 'slot1',
          child: CustomUI.text(text: 'slot child'),
        ),
        CustomUI.column(
          children: [
            CustomUI.text(text: 'nested column text'),
            CustomUI.row(
              children: [
                CustomUI.text(text: 'row child 1'),
                CustomUI.text(text: 'row child 2'),
              ],
            ),
          ],
        ),
        CustomUI.row(
          children: [
            CustomUI.text(text: 'row 1'),
            CustomUI.image(image: Link(url: 'rowImage')),
          ],
        ),
      ],
    ),
    mediaType: MediaType.audio,
    status: ReleaseStatus.releasing,
    description: 'description',
    language: 'language',
    episodes: [
      Episode(
        id: EpisodeId(uid: 'id'),
        name: 'name',
        url: 'url',
        description: 'Some',
        cover: Link(url: 'cover', header: {'header': 'header'}),
        timestamp: 'timestamp',
      ),
    ],
    cover: Link(url: 'cover', header: {'header': 'header'}),
    genres: ['genre1', 'genre2'],
    length: 10,
    meta: {'metaKey': 'metaValue'},
    poster: Link(url: 'poster', header: {'header': 'header'}),
    rating: 4.5,
    views: 100,
  ),
};

final Map<String, entrydata.EntrySaved> emptyEntrySavedList = {
  'minimal': entrydata.EntrySaved(
    savedSettings: entrydata.EntrySavedSettings(
      deleteOnFinish: true,
      downloadNextEpisodes: 2,
      hideFinishedEpisodes: true,
      onlyShowBookmarked: false,
      reverse: false,
    ),
    entry: const EntryDetailed(
      id: EntryId(uid: 'test'),
      url: 'url',
      titles: ['title'],
      mediaType: MediaType.audio,
      status: ReleaseStatus.releasing,
      description: 'description',
      language: 'language',
      episodes: [],
    ),
    boundExtensionId: 'test',
    extensionSettings: const {
      'setting': Setting(
        label: 'setting',
        visible: true,
        value: SettingValue.boolean(data: true),
        default_: SettingValue.boolean(data: true),
        ui: SettingsUI.checkBox(),
      ),
      'num': Setting(
        label: 'int',
        visible: false,
        value: SettingValue.number(data: 10.5),
        default_: SettingValue.number(data: 10.5),
        ui: SettingsUI.slider(min: 0, max: 100, step: 1),
      ),
      'stringlist': Setting(
        label: 'stringlist',
        visible: true,
        value: SettingValue.stringList(data: ['one', 'two']),
        default_: SettingValue.stringList(data: ['one', 'two']),
        ui: SettingsUI.dropdown(
          options: [
            DropdownOption(label: 'one', value: 'One'),
            DropdownOption(label: 'two', value: 'Two'),
          ],
        ),
      ),
    },
    episodedata: [
      entrydata.EpisodeData(bookmark: true, finished: false),
      entrydata.EpisodeData(bookmark: true, finished: false, progress: '0.5'),
    ],
    episode: 0,
    categories: [category],
  ),
  'comprehensive': entrydata.EntrySaved(
    savedSettings: entrydata.EntrySavedSettings(
      deleteOnFinish: true,
      hideFinishedEpisodes: true,
      onlyShowBookmarked: false,
      reverse: false,
    ),
    entry: const EntryDetailed(
      id: EntryId(uid: 'test'),
      url: 'url',
      titles: ['title'],
      mediaType: MediaType.audio,
      status: ReleaseStatus.releasing,
      description: 'description',
      language: 'language',
      episodes: [],
    ),
    boundExtensionId: 'test',
    extensionSettings: {},
    episodedata: [
      entrydata.EpisodeData(bookmark: true, finished: false),
      entrydata.EpisodeData(bookmark: true, finished: false, progress: '0.5'),
    ],
    episode: 0,
    categories: [category],
  ),
  ...emptyEntryDetailedList.map(
    (name, entry) => MapEntry(
      'entryDetailed:$name',
      entrydata.EntrySaved(
        savedSettings: entrydata.EntrySavedSettings(
          deleteOnFinish: true,
          hideFinishedEpisodes: true,
          onlyShowBookmarked: false,
          reverse: false,
        ),
        entry: entry,
        boundExtensionId: 'test',
        extensionSettings: {},
        episodedata: [
          entrydata.EpisodeData(bookmark: true, finished: false),
          entrydata.EpisodeData(
            bookmark: true,
            finished: false,
            progress: '0.5',
          ),
        ],
        episode: 0,
        categories: [category],
      ),
    ),
  ),
};

class MockExtension extends Mock implements Extension {}

const category = Category('test', DBRecord('category', 'test'), 0);

Map<String, dynamic> serialize() {
  return {
    'version': entrySerializeVersion.current,
    'entry': emptyEntryList.map(
      (key, value) => MapEntry(key, value.toEntryJson()),
    ),
    'entrysaved': emptyEntrySavedList.map(
      (key, value) => MapEntry(key, value.toEntryJson()),
    ),
  };
}

Future<void> testDeserialize(Map<String, dynamic> idata) async {
  for (final entry in (idata['entry'] as Map<String, dynamic>).entries) {
    try {
      final data = entrydata.Entry.fromJson(
        entry.value as Map<String, dynamic>,
      );
      expect(
        data,
        isA<entrydata.EntryImpl>(),
        reason:
            'Deserializing entry ${entry.key} for version ${idata['version']}',
      );
    } catch (e) {
      print(
        'Error deserializing entry ${entry.key} for version ${idata['version']}',
      );
      rethrow;
    }
  }
  for (final entry in (idata['entrysaved'] as Map<String, dynamic>).entries) {
    try {
      final data = await entrydata.EntrySaved.fromJson(
        entry.value as Map<String, dynamic>,
      );
      expect(
        data,
        isA<entrydata.EntrySaved>(),
        reason:
            'Deserializing entriesaved ${entry.key} for version ${idata['version']}',
      );
    } catch (e) {
      print(
        'Error deserializing entriesaved ${entry.key} for version ${idata['version']}',
      );
      rethrow;
    }
  }
}

void main() {
  group('Versioning', () {
    setUpAll(() {
      registerFallbackValue(emptyEntryList[0]);
      registerFallbackValue(emptyEntryDetailedList[0]);
      registerFallbackValue(emptyEntrySavedList[0]);
    });
    group('Entry', () {
      test('Write current serialization', () {
        final currfile = Directory('data')
            .sub('version')
            .sub('entry')
            .getFile('${entrySerializeVersion.current}.json');
        if (currfile.existsSync()) {
          return;
        }
        currfile.createSync(recursive: true);
        final ext = MockExtension();
        when(() => ext.id).thenReturn('test');
        currfile.writeAsStringSync(jsonEncode(serialize()));
      }, tags: ['writing']);

      test('Deserialize for every version', () async {
        final mockdb = await mockDatabase();
        final srcextension = await mockSourceExtension();
        final mockext = MockExtension();
        when(() => srcextension.getExtension(any())).thenReturn(mockext);
        when(
          () => mockdb.getCategoriesbyId([const DBRecord('category', 'test')]),
        ).thenAnswer((_) => Future.value([category]));

        for (final file in Directory(
          '',
        ).sub('data').sub('version').sub('entry').listSync()) {
          final json = jsonDecode(File(file.path).readAsStringSync());
          final data = json['entry'] as Map<String, dynamic>;
          await testDeserialize(data);
        }
      });
    });

    group('Database', () {
      setUpAll(() async => await metis.SurrealDB.ensureInitialized());
      test('Write current DB version', () async {
        final db = Database();
        final path =
            (Directory('data').sub('version').sub('database')
                  ..createSync(recursive: true))
                .sub('$dbVersion');
        if (path.existsSync()) {
          return;
        }
        await db.initDB(
          await AdapterSurrealDB.connect('surrealkv://${path.absolute.path}'),
        );
        final ext = MockExtension();
        when(() => ext.id).thenReturn('test');
        await db.updateCategory(category);
        for (final entry in emptyEntrySavedList.values) {
          await db.updateEntry(entry);
        }
        db.db.dispose();
        await Future.delayed(const Duration(milliseconds: 100));
      }, tags: ['writing']);

      test('Read all DB versions', () async {
        final srcextension = await mockSourceExtension();
        final mockext = MockExtension();
        when(() => srcextension.getExtension(any())).thenReturn(mockext);
        for (final file in Directory('data/version/database').listSync()) {
          final db = Database();
          await db.initDB(
            await AdapterSurrealDB.connect('surrealkv://${file.path}'),
          );
          await db.getEntries(0, 100).toList();
          db.db.dispose();
        }
      });
    });

    group('Backup', () {
      test('Create Backup', () async {
        final file =
            (Directory('data').sub('version').sub('backup')
                  ..createSync(recursive: true))
                .getFile('$archiveVersion.dpkg');
        if (file.existsSync()) {
          return;
        }
        final mockdb = await mockDatabase();
        when(
          () => mockdb.getCategoriesbyId([const DBRecord('category', 'test')]),
        ).thenAnswer((_) => Future.value([category]));
        final mockext = MockExtension();
        when(
          () => mockdb.getEntries(any(), any()),
        ).thenAnswer((_) => Stream.fromIterable(emptyEntrySavedList.values));

        when(() => mockext.id).thenReturn('test');
        final archive = await createBackup();

        await file.create(recursive: true);
        await file.writeAsBytes(ZipEncoder().encodeBytes(archive));
      }, tags: ['writing']);

      test('Apply Backup', () async {
        final mockdb = await mockDatabase();
        when(
          () => mockdb.getCategoriesbyId([const DBRecord('category', 'test')]),
        ).thenAnswer((_) => Future.value([category]));
        when(() => mockdb.updateEntry(any())).thenAnswer((args) async {
          final data = args.positionalArguments[0];
          expect(data, isNotNull);
        });
        final mockext = MockExtension();
        when(
          () => mockdb.getEntries(any(), any()),
        ).thenAnswer((_) => Stream.fromIterable(emptyEntrySavedList.values));

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
