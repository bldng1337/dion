/// Regression tests for every serialized surface of the app.
///
/// Covered surfaces (everything produced/consumed by dionysos itself, not
/// dion-runtime internals):
///
/// | Surface                    | Data format        | Versioned by                |
/// |----------------------------|--------------------|-----------------------------|
/// | Entry / EntrySaved         | JSON               | `entrySerializeVersion`     |
/// | Category                   | JSON / DB          | `categorySerializeVersion`  |
/// | ExtensionMetaData          | JSON / DB          | `extensionSerializeVersion` |
/// | Whole database             | surrealkv files    | `dbVersion`                 |
/// | Backup                     | `.dpkg` zip        | `archiveVersion`            |
///
/// Fixture generation is split from verification:
///
/// ```sh
/// # Once per version bump (or fresh checkout): also regenerates fixtures.
/// DION_WRITE_VERSIONING_FIXTURES=1 \
///   flutter test -d windows integration_test/versioning_test.dart
///
/// # Every run afterwards: verifies against `.versioning_data/` only.
/// flutter test -d windows integration_test/versioning_test.dart
/// ```
///
/// The writing pass serializes the current schema into `.versioning_data/`,
/// one file/directory per version, and never overwrites existing ones; every
/// prior version kept there is verified for compatibility on each run. The
/// directory is gitignored: fixtures describe *local* serialization history,
/// and regeneration is cheap.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dionysos/data/activity/activity.dart';
import 'package:dionysos/data/activity/episode.dart';
import 'package:dionysos/data/category.dart';
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/extension.dart';
import 'package:dionysos/data/versioning.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/views/settings/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metis/metis.dart' as metis;
import 'package:mocktail/mocktail.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

import 'utils/mock.dart';

// ---------------------------------------------------------------------------
// Fixture locations
// ---------------------------------------------------------------------------

final Directory _fixtures = Directory('.versioning_data').absolute;

/// Fixture writers are only *registered* when regeneration is requested,
/// mirroring the previous `dart_test.yaml` tag-skip behaviour without
/// depending on runner flag support in `flutter test`.
final bool _writingEnabled =
    Platform.environment['DION_WRITE_VERSIONING_FIXTURES'] == '1';

Directory get _entryFixtures => _fixtures.sub('entry');
Directory get _categoryFixtures => _fixtures.sub('category');
Directory get _extensionMetaFixtures => _fixtures.sub('extension_meta');
Directory get _databaseFixtures => _fixtures.sub('database');
Directory get _backupFixtures => _fixtures.sub('backup');

/// Fails unless the current-version fixture exists under [root], telling the
/// developer exactly how to produce it. Without this, a fresh checkout would
/// silently report success while verifying nothing.
void _requireFixture(Directory root, String surface, int currentVersion) {
  final current =
      root.getFile('$currentVersion.json').existsSync() ||
      root.sub('$currentVersion').existsSync();
  if (!current) {
    fail(
      'No $surface fixture for the current schema version ($currentVersion).\n'
      '${_regenerationHint(root)}',
    );
  }
}

String _regenerationHint(Directory root) =>
    'Run:\n'
    '  DION_WRITE_VERSIONING_FIXTURES=1 flutter test -d windows \\\n'
    '    integration_test/versioning_test.dart\n'
    'to produce it locally (${root.absolute.path}, gitignored).';

// ---------------------------------------------------------------------------
// Failure reporting
//
// Instead of failing fast, every checked item contributes a formatted record
// (surface, format, version, sample, error). The summary is thrown at the end
// of each reader test so one run reports everything that broke.
// ---------------------------------------------------------------------------

final List<String> _failureLog = [];

void _recordFailure({
  required String surface,
  required String format,
  required String version,
  required String sample,
  required Object error,
  required StackTrace stackTrace,
}) {
  final stackLines = stackTrace.toString().split('\n').take(6).join('\n    ');
  _failureLog.add(
    '[surface=$surface format=$format version=$version sample=$sample]\n'
    '    $error\n'
    '    $stackLines',
  );
}

Future<void> _guarded(
  FutureOr<void> Function() body, {
  required String surface,
  required String format,
  required String version,
  required String sample,
}) async {
  try {
    await body();
  } catch (e, s) {
    _recordFailure(
      surface: surface,
      format: format,
      version: version,
      sample: sample,
      error: e,
      stackTrace: s,
    );
  }
}

void _guardedSync(
  FutureOr<void> Function() body, {
  required String surface,
  required String format,
  required String version,
  required String sample,
}) {
  try {
    final result = body();
    if (result is Future) {
      // Only reached if someone made a previously-sync check async.
      unawaited(
        result.catchError((Object e, StackTrace s) {
          _recordFailure(
            surface: surface,
            format: format,
            version: version,
            sample: sample,
            error: e,
            stackTrace: s,
          );
        }),
      );
    }
  } catch (e, s) {
    _recordFailure(
      surface: surface,
      format: format,
      version: version,
      sample: sample,
      error: e,
      stackTrace: s,
    );
  }
}

/// Throws a combined failure listing every recorded problem for the test.
/// All tests in this file share one isolate, so the log is drained here to
/// keep each test's report scoped to its own checks.
void _rethrowFailures(String scope) {
  if (_failureLog.isEmpty) return;
  final report = _failureLog.join('\n---\n');
  final count = _failureLog.length;
  _failureLog.clear();
  fail('$scope failed ($count problem${count == 1 ? '' : 's'}):\n$report');
}

// ---------------------------------------------------------------------------
// Deep-diff of JSON trees, used to detect lossy round-trips
// ---------------------------------------------------------------------------

List<String> _deepDiff(Object? expected, Object? actual, String path) {
  if (expected is Map && actual is Map) {
    final diffs = <String>[];
    for (final key in expected.keys) {
      if (!actual.containsKey(key)) {
        diffs.add('$path.$key: dropped during round-trip');
      } else {
        diffs.addAll(_deepDiff(expected[key], actual[key], '$path.$key'));
      }
    }
    for (final key in actual.keys.toSet().difference(expected.keys.toSet())) {
      diffs.add("'$path.$key': appeared during round-trip");
    }
    return diffs;
  }
  if (expected is List && actual is List) {
    if (expected.length != actual.length) {
      return ['$path: length ${expected.length} -> ${actual.length}'];
    }
    return [
      for (var i = 0; i < expected.length; i++)
        ..._deepDiff(expected[i], actual[i], '$path[$i]'),
    ];
  }
  // Normalized trees hold only Maps, Lists, Strings, nums, bools and null.
  return expected == actual ? const [] : ['$path: $expected != $actual'];
}

/// Sends [value] through a JSON encode/decode cycle so freshly built sample
/// objects and values loaded back from disk can be compared structurally.
dynamic _normalized(Object? value) => jsonDecode(jsonEncode(value));

void _assertLosslessRoundTrip(
  Object? reserialized,
  Object? original,
  String what,
) {
  final diffs = _deepDiff(original, reserialized, what);
  if (diffs.isNotEmpty) {
    throw StateError(
      'round-trip is not lossless, ${diffs.length} difference(s):\n'
      '    ${diffs.take(20).join('\n    ')}',
    );
  }
}

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

const _boundExtensionId = 'test.extension';

const _categories = [
  Category('Reading', metis.DBRecord('category', 'cat-reading'), 0),
  Category('Watching', metis.DBRecord('category', 'cat-watching'), 1),
];

EntryImpl get minimalEntry => const EntryImpl(
  rust.Entry(
    id: rust.EntryId(uid: 'entry-minimal'),
    url: 'https://example.com/minimal',
    title: 'Minimal Entry',
    mediaType: rust.MediaType.comic,
    cover: rust.Link(url: 'https://img.example.com/minimal.jpg'),
  ),
  _boundExtensionId,
);

/// Flat entry exercising every optional [rust.Entry] field.
EntryImpl get comprehensiveBasicEntry => const EntryImpl(
  rust.Entry(
    id: rust.EntryId(uid: 'entry-comprehensive', iddata: ' Comprehensive'),
    url: 'https://example.com/comprehensive',
    title: 'Comprehensive Entry',
    mediaType: rust.MediaType.book,
    cover: rust.Link(url: 'https://img.example.com/cover.jpg', header: {
      'Authorization': 'Bearer token',
      'Cookie': 'session=abc',
    }),
    author: ['Author One', 'Author Two'],
    rating: 4.5,
    views: 100.5,
    length: 312,
  ),
  _boundExtensionId,
);

const _episodes = [
  rust.Episode(
    id: rust.EpisodeId(uid: 'ep-1'),
    name: 'First',
    url: 'https://cdn.example.com/1',
  ),
  rust.Episode(
    id: rust.EpisodeId(uid: 'ep-2', iddata: 'x2'),
    name: 'Second',
    description: 'with description',
    url: 'https://cdn.example.com/2',
    cover: rust.Link(url: 'https://img.example.com/ep2.jpg', header: {'Cookie': 'c=1'}),
    timestamp: '2026-01-02T03:04:05Z',
  ),
];

/// A [rust.CustomUI] tree exercising *every* widget variant of the runtime
/// schema plus both interaction kinds, so payload drift cannot hide in an
/// uncovered branch.
const rust.CustomUI comprehensiveCustomUI = rust.CustomUI.column(
  scrollable: false,
  mainAxisAlignment: rust.MainAxisAlignment.spaceBetween,
  crossAxisAlignment: rust.CrossAxisAlignment.stretch,
  mainAxisSize: rust.MainAxisSize.max,
  children: [
    // Leaf widgets ---------------------------------------------------------
    rust.CustomUI.text(text: 'plain text'),
    rust.CustomUI.text(
      text: 'styled text',
      style: rust.TextStyle(
        bold: true,
        italic: false,
        underline: true,
        strikethrough: false,
        code: true,
        fontSize: 15,
      ),
    ),
    rust.CustomUI.image(
      image: rust.Link(url: 'https://img.example.com/a.jpg'),
      width: 120,
      height: 80,
    ),
    rust.CustomUI.link(link: 'https://example.com', label: 'link label'),
    rust.CustomUI.timestamp(
      timestamp: '2026-08-27T00:00:00Z',
      display: rust.TimestampType.relative,
    ),
    rust.CustomUI.spinner(),
    rust.CustomUI.divider(),
    rust.CustomUI.starDisplay(fill: 3.5, maxStars: 5),
    rust.CustomUI.foldableText(
      text: 'foldable text',
      maxLines: 4,
      animate: false,
    ),
    // Interactions -----------------------------------------------------------
    rust.CustomUI.button(
      label: 'Invoke button',
      onClick: rust.Interaction.invoke(handler: 'onTap', payload: '{}'),
      buttonType: rust.ButtonType.elevated,
      color: rust.ColorToken.primaryContainer,
    ),
    rust.CustomUI.button(
      label: 'WriteKey button',
      onClick: rust.Interaction.writeKey(key: 'key', value: 'value'),
      buttonType: rust.ButtonType.ghost,
      color: rust.ColorToken.error,
    ),
    rust.CustomUI.inlineSetting(
      settingId: 'inline-setting',
      settingKind: rust.SettingKind.search,
      onCommit: rust.Interaction.invoke(handler: 'commit', payload: 'x'),
    ),
    rust.CustomUI.textInput(
      onChange: rust.Interaction.writeKey(key: 'query', value: ''),
      debounceMs: 250,
      initial: 'initial value',
      onCommit: rust.Interaction.invoke(handler: 'search', payload: ''),
    ),
    rust.CustomUI.dropdown(
      items: [
        rust.DropdownItem(label: 'One', value: 'one'),
        rust.DropdownItem(label: 'Two', value: 'two'),
      ],
      initialValue: 'one',
      onChange: rust.Interaction.invoke(handler: 'pick', payload: ''),
    ),
    // Feeds, cards, slots ------------------------------------------------------
    rust.CustomUI.feed(handler: 'feedHandler', data: 'feedData'),
    rust.CustomUI.card(
      image: rust.Link(url: 'https://img.example.com/card.jpg'),
      top: rust.CustomUI.text(text: 'card top'),
      bottom: rust.CustomUI.text(text: 'card bottom'),
      onClick: rust.Interaction.writeKey(key: 'cardKey', value: 'cardValue'),
    ),
    rust.CustomUI.slot(
      handler: 'slotHandler',
      child: rust.CustomUI.text(text: 'slot child'),
      staticData: '{"page":0}',
      subscriptions: [
        rust.Subscription(
          source: rust.SubscriptionSource.store(),
          key: 'storeKey',
          stateKey: 'stateStore',
        ),
        rust.Subscription(
          source: rust.SubscriptionSource.setting(kind: rust.SettingKind.extension_),
          key: 'settingKey',
          stateKey: 'stateSetting',
        ),
        rust.Subscription(
          source: rust.SubscriptionSource.entrySetting(),
          key: 'entrySettingKey',
          stateKey: 'stateEntrySetting',
        ),
      ],
    ),
    rust.CustomUI.listTile(
      leading: rust.CustomUI.badge(child: rust.CustomUI.text(text: '!'), color: rust.ColorToken.error),
      title: rust.CustomUI.text(text: 'tile title'),
      subtitle: rust.CustomUI.link(link: 'https://tile.example.com'),
      trailing: rust.CustomUI.timestamp(timestamp: 'ts', display: rust.TimestampType.absolute),
      onClick: rust.Interaction.invoke(handler: 'tileTap', payload: ''),
      onLongClick: rust.Interaction.writeKey(key: 'tileKey', value: ''),
    ),
    rust.CustomUI.container(
      child: rust.CustomUI.text(text: 'contained'),
      containerType: rust.ContainerType.outlined,
      color: rust.ColorToken.surfaceContainerHighest,
      borderColor: rust.ColorToken.onError,
      padding: rust.EdgeInsets(left: 4, top: 2, right: 4, bottom: 2),
      width: 200,
      height: 64,
      alignment: rust.Alignment.centerLeft,
      emphasized: true,
    ),
    rust.CustomUI.clickable(
      child: rust.CustomUI.text(text: 'click me'),
      onClick: rust.Interaction.invoke(handler: 'click', payload: ''),
      onLongClick: rust.Interaction.writeKey(key: 'longClickKey', value: ''),
    ),
    rust.CustomUI.padding(
      padding: rust.EdgeInsets(bottom: 8),
      child: rust.CustomUI.badge(
        child: rust.CustomUI.spinner(),
        color: rust.ColorToken.secondary,
      ),
    ),
    rust.CustomUI.expanded(
      child: rust.CustomUI.center(child: rust.CustomUI.divider()),
      flex: 2,
    ),
    rust.CustomUI.sizedBox(width: 24, height: 24),
    rust.CustomUI.spacer(flex: 3),
    rust.CustomUI.wrap(
      children: [rust.CustomUI.divider(), rust.CustomUI.spinner()],
      spacing: 4,
      runSpacing: 2,
      alignment: rust.WrapAlignment.spaceEvenly,
    ),
    rust.CustomUI.align(
      alignment: rust.Alignment.bottomRight,
      child: rust.CustomUI.text(text: 'aligned'),
    ),
    rust.CustomUI.stack(
      children: [rust.CustomUI.text(text: 'stacked'), rust.CustomUI.spinner()],
      alignment: rust.Alignment.topCenter,
      fit: rust.StackFit.loose,
    ),
    // Nesting --------------------------------------------------------------------
    rust.CustomUI.row(
      scrollable: true,
      children: [
        rust.CustomUI.image(image: rust.Link(url: 'https://img.example.com/row.jpg')),
        rust.CustomUI.text(text: 'right sibling'),
      ],
    ),
    rust.CustomUI.column(
      scrollable: true,
      children: [rust.CustomUI.text(text: 'nested column text')],
    ),
    rust.CustomUI.entryCard(
      entry: rust.Entry(
        id: rust.EntryId(uid: 'nested-card-entry'),
        url: 'https://example.com/nested-card',
        title: 'Nested Card Entry',
        mediaType: rust.MediaType.video,
      ),
    ),
  ],
);

rust.EntryDetailed get comprehensiveDetailed => const rust.EntryDetailed(
  id: rust.EntryId(uid: 'entry-comprehensive-detailed', iddata: ' Detailed'),
  url: 'https://example.com/comprehensive-detailed',
  titles: ['Comprehensive Detailed', 'Second Title'],
  author: ['Author One', 'Author Two'],
  ui: comprehensiveCustomUI,
  mediaType: rust.MediaType.audio,
  status: rust.ReleaseStatus.releasing,
  description: 'A deliberately exhaustive entry',
  language: 'en',
  cover: rust.Link(url: 'https://img.example.com/detailed.jpg', header: {'Authorization': 'Bearer t'}),
  poster: rust.Link(url: 'https://img.example.com/poster.jpg'),
  episodes: _episodes,
  genres: ['genre1', 'genre2'],
  meta: {'metaKey': 'metaValue'},
  rating: 4.5,
  views: 100.5,
  length: 10,
);

/// One [rust.Setting] per [rust.SettingValue] x [rust.SettingsUI] combination.
Map<String, rust.Setting> get comprehensiveExtensionSettings => const {
  'boolean': rust.Setting(
    label: 'checkbox setting',
    visible: true,
    value: rust.SettingValue.boolean(data: true),
    default_: rust.SettingValue.boolean(data: false),
    ui: rust.SettingsUI.checkBox(),
  ),
  'number': rust.Setting(
    label: 'slider setting',
    visible: false,
    value: rust.SettingValue.number(data: 7.5),
    default_: rust.SettingValue.number(data: 0),
    ui: rust.SettingsUI.slider(min: 0, max: 100, step: 1),
  ),
  'string': rust.Setting(
    label: 'dropdown setting',
    visible: true,
    value: rust.SettingValue.string(data: 'two'),
    default_: rust.SettingValue.string(data: 'one'),
    ui: rust.SettingsUI.dropdown(
      options: [
        rust.DropdownOption(label: 'one', value: 'One'),
        rust.DropdownOption(label: 'two', value: 'Two'),
      ],
    ),
  ),
  'stringlist': rust.Setting(
    label: 'multi dropdown setting',
    visible: true,
    value: rust.SettingValue.stringList(data: ['a', 'b']),
    default_: rust.SettingValue.stringList(data: []),
    ui: rust.SettingsUI.multiDropdown(
      options: [rust.DropdownOption(label: 'a', value: 'A')],
    ),
  ),
  'customui': rust.Setting(
    label: 'custom ui setting',
    visible: true,
    value: rust.SettingValue.string(data: 'payload'),
    default_: rust.SettingValue.string(data: ''),
    ui: rust.SettingsUI.customUi(ui: rust.CustomUI.text(text: 'custom')),
  ),
};

List<EntrySaved> get savedEntrySamples => [
  // Plain minimal record.
  EntrySaved(
    entry: const rust.EntryDetailed(
      id: rust.EntryId(uid: 'saved-minimal'),
      url: 'https://example.com/saved-minimal',
      titles: ['Saved Minimal'],
      mediaType: rust.MediaType.book,
      status: rust.ReleaseStatus.complete,
      description: 'minimal saved entry',
      language: 'en',
      episodes: [],
    ),
    categories: [_categories.first],
    savedSettings: EntrySavedSettings(deleteOnFinish: true, downloadNextEpisodes: 2),
    boundExtensionId: _boundExtensionId,
    extensionSettings: {},
    episode: 1,
    episodedata: [
      EpisodeData(bookmark: true, finished: true),
      EpisodeData(bookmark: false, finished: false, progress: '0.42'),
    ],
  ),
  // Everything populated, including quotes/images and per-entry extensions.
  EntrySaved(
    entry: comprehensiveDetailed,
    categories: _categories,
    savedSettings: EntrySavedSettings(
      reverse: true,
      hideFinishedEpisodes: true,
      onlyShowBookmarked: true,
      downloadNextEpisodes: 5,
      deleteOnFinish: true,
    ),
    boundExtensionId: _boundExtensionId,
    extensionSettings: comprehensiveExtensionSettings,
    episode: 0,
    episodedata: [
      EpisodeData.empty(),
      EpisodeData(
        bookmark: true,
        finished: false,
        progress: '12.75',
        quotes: [
          SavedQuote(text: 'quote text', savedAt: DateTime.utc(2026, 1, 2, 3, 4, 5)),
          SavedQuote(text: 'second quote', savedAt: DateTime.utc(2026, 2, 3)),
        ],
        images: [
          SavedImage(
            url: 'https://img.example.com/saved.jpg',
            headers: const {'Referer': 'https://example.com'},
            savedAt: DateTime.utc(2026, 3, 4),
          ),
        ],
      ),
    ],
    entryExtensions: [
      EntryExtension(extensionId: 'entry.ext.a', extensionSettings: comprehensiveExtensionSettings),
      EntryExtension(extensionId: 'entry.ext.b', extensionSettings: {}, ui: const rust.CustomUI.text(text: 'extension ui')),
    ],
    sourceExtensions: [
      EntryExtension(extensionId: 'source.ext.a', extensionSettings: {}),
    ],
  ),
];

/// Catalogue of what the writer seeds; reused by readers for assertions.
final List<Activity> activitySamples = [
  Activity(DateTime.utc(2026, 8, 1, 10, 30), 'act-base'),
  EpisodeActivity(
    fromepisode: 1,
    toepisode: 2,
    entry: minimalEntry,
    extensionid: _boundExtensionId,
    duration: const Duration(minutes: 25, seconds: 17),
    time: DateTime.utc(2026, 8, 2, 21, 45),
    id: 'act-episode',
  ),
];

List<ExtensionMetaData> get extensionMetaSamples => const [
  ExtensionMetaData('ext-one', true),
  ExtensionMetaData('ext-two', false, searchEnabled: false),
];

// ---------------------------------------------------------------------------
// Legacy payloads for pre-migration decode branches in Entry.fromJson /
// EntrySaved.fromJson (flat fields, camelCase mediaType, 'settings' key).
// These are synthesized in-code so the old branches stay covered forever
// without shipping ancient fixture files in the repository.
// ---------------------------------------------------------------------------

Map<String, dynamic> _legacyV1Entry() => {
  'version': 1,
  'extensionid': _boundExtensionId,
  'entry': {
    'id': 'legacy-entry',
    'mediaType': 'Book',
    'url': 'https://legacy.example.com/e1',
    'title': 'Legacy Entry',
    'cover': 'https://legacy.example.com/c.jpg',
    'coverHeader': {'k': 'v'},
    'author': ['legacy author'],
    'rating': 3.5,
    'views': 12.0,
    'length': 240,
  },
};

Map<String, dynamic> _legacyV1Saved() => {
  'version': 1,
  'extensionid': _boundExtensionId,
  'entry': {
    'id': 'legacy-saved',
    'mediaType': 'Comic',
    'status': 'Releasing',
    'url': 'https://legacy.example.com/s1',
    'title': 'Legacy Saved',
    'author': ['legacy author'],
    'cover': 'https://legacy.example.com/sc.jpg',
    'coverHeader': {'k': 'v'},
    'description': 'legacy description',
    'language': 'en',
    'genres': ['legacy'],
    'length': 32,
    'meta': {'mk': 'mv'},
    'rating': 4.0,
    'views': 99.0,
    'episodes': [
      {
        'id': 'legacy-ep',
        'name': 'Legacy Episode',
        'url': 'https://legacy.example.com/le1',
        'cover': 'https://legacy.example.com/lec.jpg',
        'coverheader': {'k': 'v'},
        'description': 'legacy ep description',
        'timestamp': '2020-01-01T00:00:00Z',
      },
    ],
  },
  'categories': [
    {'tb': 'category', 'id': 'cat-legacy'},
  ],
  'episodedata': [
    {'bookmark': true, 'finished': false, 'progress': '0.9'},
  ],
  'episode': 0,
  'settings': {
    'reverse': false,
    'hideFinishedEpisodes': true,
    'downloadNextEpisodes': 3,
    'deleteOnFinish': false,
    'onlyShowBookmarked': false,
  },
};

/// Rewrites a currently-shaped [EntrySaved.toJson] payload into the flat v1
/// archive layout consumed by [applyBackup]'s legacy branch.
Map<String, dynamic> _legacyV1BackupEntry(EntrySaved saved) {
  final detailed = saved.entry;
  return {
    'version': 1,
    'extensionid': saved.boundExtensionId,
    'entry': {
      'id': detailed.id.uid,
      'mediaType': detailed.mediaType.toJson(),
      'status': detailed.status.toJson(),
      'url': detailed.url,
      'title': detailed.titles.first,
      'author': detailed.author,
      // The v1 layout carries a mandatory flat cover link.
      'cover': detailed.cover?.url ?? 'https://legacy.example.com/cover.jpg',
      'coverHeader': detailed.cover?.header,
      'description': detailed.description,
      'language': detailed.language,
      'episodes': [
        for (final episode in detailed.episodes)
          {
            'id': episode.id.uid,
            'name': episode.name,
            'url': episode.url,
            'cover': episode.cover?.url,
            'coverheader': episode.cover?.header,
            'description': episode.description,
            'timestamp': episode.timestamp,
          },
      ],
    },
    'categories': [],
    'episodedata': [for (final ed in saved.episodedata) ed.toJson()],
    'episode': saved.episode,
    'settings': saved.savedSettings.toJson(),
  };
}


// ---------------------------------------------------------------------------
// Database seeding
// ---------------------------------------------------------------------------

/// Opens an in-memory database on the production initialization path.
/// Connects directly instead of going through [Database.init] so the FRB
/// runtime initialized once in setUpAll is not re-initialized.
Future<Database> _openMemoryDb({required bool seed}) async {
  final db = Database();
  await db.initDB(await metis.AdapterSurrealDB.connect('memory://'));
  if (seed) {
    for (final category in _categories) {
      await db.updateCategory(category);
    }
    for (final meta in extensionMetaSamples) {
      await db.setExtensionMetaData(meta);
    }
    for (final activity in activitySamples) {
      await db.addActivity(activity);
    }
    for (final entry in savedEntrySamples) {
      await db.addEntry(entry);
    }
  }
  register<Database>(db);
  return db;
}

/// Windows keeps the KV directory locked briefly after dispose.
Future<void> _closeDb(Database db) async {
  db.db.dispose();
  await Future<void>.delayed(const Duration(milliseconds: 150));
}

/// Opens a file-backed store. Windows can keep surrealkv files locked for a
/// moment after a previous handle closes (os error 33), so opening retries
/// briefly instead of reporting that race as a versioning failure.
Future<metis.AdapterSurrealDB> _connectStore(Directory dir) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  var delay = const Duration(milliseconds: 100);
  while (true) {
    try {
      return await metis.AdapterSurrealDB.connect(
        'surrealkv://${dir.absolute.path}',
      );
    } catch (e) {
      final lockError = e.toString().contains('os error 33');
      if (!lockError || DateTime.now().isAfter(deadline)) rethrow;
      await Future<void>.delayed(delay);
      delay *= 2;
    }
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(const metis.DBRecord('category', 'fallback'));
    return metis.SurrealDB.ensureInitialized();
  });

  if (_writingEnabled) {
    group('fixture generation', () {
      test('write current serialization', () async {
        Future<void> writeFixture(
          String dirName,
          int version,
          Object payload,
        ) async {
          final file = _fixtures.sub(dirName).getFile('$version.json');
          if (file.existsSync()) {
            // ignore: avoid_print
            print('skipping ${file.path}: fixture already exists');
            return;
          }
          file.parent.createSync(recursive: true);
          await file.writeAsString(
            const JsonEncoder.withIndent('  ').convert(payload),
          );
        }

        await writeFixture('entry', entrySerializeVersion.current, {
          'serializeVersion': entrySerializeVersion.current,
          'entries': {
            'minimal': minimalEntry.toEntryJson(),
            'comprehensive': comprehensiveBasicEntry.toEntryJson(),
          },
          'saved': {
            for (final (i, saved) in savedEntrySamples.indexed)
              'saved-$i': saved.toJson(),
          },
        });
        await writeFixture('category', categorySerializeVersion.current, {
          'serializeVersion': categorySerializeVersion.current,
          'items': [for (final c in _categories) c.toJson()],
        });
        await writeFixture(
          'extension_meta',
          extensionSerializeVersion.current,
          {
            'serializeVersion': extensionSerializeVersion.current,
            'items': [for (final m in extensionMetaSamples) m.toDBJson()],
          },
        );
      });

      test('write current db version', () async {
        final target = _databaseFixtures.sub('$dbVersion');
        if (target.existsSync()) {
          // ignore: avoid_print
          print('skipping ${target.path}: fixture already exists');
          return;
        }
        target.createSync(recursive: true);
        final db = Database();
        try {
          await db.initDB(await _connectStore(target));
          for (final category in _categories) {
            await db.updateCategory(category);
          }
          for (final meta in extensionMetaSamples) {
            await db.setExtensionMetaData(meta);
          }
          for (final activity in activitySamples) {
            await db.addActivity(activity);
          }
          for (final entry in savedEntrySamples) {
            await db.addEntry(entry);
          }
        } finally {
          await _closeDb(db);
        }
      });

      test('create current backup archive', () async {
        final file = _backupFixtures.getFile('$archiveVersion.dpkg');
        if (file.existsSync()) {
          // ignore: avoid_print
          print('skipping ${file.path}: fixture already exists');
          return;
        }
        final db = await _openMemoryDb(seed: true);
        final archive = await createBackup();
        await _closeDb(db);
        await file.create(recursive: true);
        await file.writeAsBytes(ZipEncoder().encodeBytes(archive));
      });
    });
  }

  group('JSON schema', () {

    test('deserialize and round-trip every stored version', () async {
      // EntrySaved.fromJson resolves category records through the database.
      final mockdb = await mockDatabase();
      when(() => mockdb.getCategoriesbyId(any())).thenAnswer((invocation) async {
        final ids = invocation.positionalArguments[0] as Iterable<metis.DBRecord>;
        return [
          for (final id in ids)
            _categories.firstWhere(
              (c) => c.id.id == id.id,
              orElse: () => throw StateError('mock database holds no category ${id.id}'),
            ),
        ];
      });

      await _checkEntryJsonVersions();
      await _checkSimpleJsonSurfaces();

      _rethrowFailures('JSON schema');
    });
  });

  group('Database', () {
    test('read, migrate and round-trip every stored version', () async {
      if (!_databaseFixtures.existsSync()) {
        fail(_regenerationHint(_databaseFixtures));
      }
      _requireFixture(_databaseFixtures, 'database', dbVersion);

      for (final entity in _databaseFixtures.listSync()) {
        if (entity is! Directory) continue;
        final version = entity.name;
        Database? opened;
        await _guarded(
          () async {
            final db = Database();
            await db.initDB(await _connectStore(entity));
            opened = db;
            await _verifySeededContent(db);
          },
          surface: 'database',
          format: 'surrealkv',
          version: version,
          sample: 'whole store',
        );
        if (opened != null) {
          await _closeDb(opened!);
        }
      }
      _rethrowFailures('Database');
    });
  });

  group('Backup', () {
    test('apply every stored backup version', () async {
      final hasBackups =
          _backupFixtures.existsSync() &&
          _backupFixtures.listSync().whereType<File>().any(
            (f) => f.extension == '.dpkg',
          );
      if (!hasBackups) {
        fail(_regenerationHint(_backupFixtures));
      }

      for (final entity in _backupFixtures.listSync()) {
        if (entity is! File || entity.extension != '.dpkg') continue;
        final version = entity.filenameWithoutExtension;
        await _guarded(
          () async {
            final db = await _openMemoryDb(seed: false);
            // Apply resolves category names against the target database.
            for (final category in _categories) {
              await db.updateCategory(category);
            }
            final archive = ZipDecoder().decodeBytes(await entity.readAsBytes());
            await applyBackup(archive);
            await _verifyRestoredBackup(db);
            await _closeDb(db);
          },
          surface: 'backup',
          format: 'dpkg',
          version: version,
          sample: entity.filename,
        );
      }

      // Synthetic archive in the pre-v2 layout (entries only, no activities).
      await _guarded(
        () async {
          final db = await _openMemoryDb(seed: false);
          final archive =
              Archive()
                ..addFile(
                  ArchiveFile.string('dionmeta.json', json.encode({'version': 1})),
                )
                ..addFile(
                  ArchiveFile.string(
                    'entrydata.json',
                    json.encode([
                      for (final saved in savedEntrySamples)
                        _legacyV1BackupEntry(saved),
                    ]),
                  ),
                );
          await applyBackup(archive);
          final restored = await db.getEntries(0, 100).toList();
          if (restored.length != savedEntrySamples.length) {
            throw StateError(
              'expected ${savedEntrySamples.length} restored entries, got '
              '${restored.length}',
            );
          }
          await _closeDb(db);
        },
        surface: 'backup',
        format: 'dpkg',
        version: '<=1-synthetic',
        sample: 'entries-only layout',
      );

      _rethrowFailures('Backup');
    });
  });

  group('Legacy decode', () {
    test('flat v1 payloads still decode', () {
      _guardedSync(
        () {
          final parsed = Entry.fromJson(_legacyV1Entry());
          if (parsed.title != 'Legacy Entry' ||
              parsed.mediaType != rust.MediaType.book ||
              parsed.rating != 3.5) {
            throw StateError(
              'legacy v1 entry decoded wrong: '
              '${parsed.title} / ${parsed.mediaType} / ${parsed.rating}',
            );
          }
        },
        surface: 'json',
        format: 'Entry.json',
        version: '1',
        sample: 'legacy-entry',
      );

      _guardedSync(
        () async {
          final parsed = await EntrySaved.fromJson(_legacyV1Saved());
          if (parsed.boundExtensionId != _boundExtensionId ||
              parsed.episode != 0) {
            throw StateError('legacy v1 saved lost identity fields');
          }
          if (parsed.savedSettings.downloadNextEpisodes.value != 3) {
            throw StateError(
              'legacy v1 savedSettings lost downloadNextEpisodes',
            );
          }
          if (parsed.categories.single.id.id != 'cat-legacy') {
            throw StateError('legacy v1 categories resolved wrong');
          }
        },
        surface: 'json',
        format: 'EntrySaved.json',
        version: '1',
        sample: 'legacy-saved',
      );

      _rethrowFailures('Legacy decode');
    });

    test('unsupported versions are rejected', () {
      for (final badVersion in [-1, 0, 999]) {
        final versionSupported =
            badVersion >= entrySerializeVersion.minimum &&
            badVersion <= entrySerializeVersion.current;
        if (versionSupported) continue;

        Object? rejectedEntry;
        try {
          Entry.fromJson({'version': badVersion});
        } catch (_) {
          rejectedEntry = true;
        }
        expect(
          rejectedEntry,
          isNotNull,
          reason: 'Entry.fromJson accepted out-of-range version $badVersion',
        );
      }
    });
  });
}

// ---------------------------------------------------------------------------
// Reader helpers
// ---------------------------------------------------------------------------

Future<void> _checkEntryJsonVersions() async {
  if (!_entryFixtures.existsSync()) {
    fail(_regenerationHint(_entryFixtures));
  }
  _requireFixture(_entryFixtures, 'entry-json', entrySerializeVersion.current);

  for (final entity in _entryFixtures.listSync()) {
    if (entity is! File || entity.extension != '.json') continue;
    final version = entity.filenameWithoutExtension;

    await _guarded(
      () async {
        final document =
            jsonDecode(await entity.readAsString()) as Map<String, dynamic>;

        for (final sample
            in (document['entries'] as Map<String, dynamic>).entries) {
          await _guarded(
            () {
              final parsed = Entry.fromJson(
                sample.value as Map<String, dynamic>,
              );
              if (parsed is! EntryImpl) {
                throw StateError(
                  'decoded to ${parsed.runtimeType}, expected EntryImpl',
                );
              }
              _assertLosslessRoundTrip(
                _normalized(parsed.toEntryJson()),
                _normalized(sample.value),
                'Entry',
              );
            },
            surface: 'entry-json',
            format: 'Entry.json',
            version: version,
            sample: sample.key,
          );
        }

        for (final sample
            in (document['saved'] as Map<String, dynamic>).entries) {
          await _guarded(
            () async {
              final parsed = await EntrySaved.fromJson(
                _hydrateRecordMaps(sample.value),
              );
              _assertLosslessRoundTrip(
                _normalized(parsed.toJson()),
                _normalized(sample.value),
                'EntrySaved',
              );
            },
            surface: 'entry-json',
            format: 'EntrySaved.json',
            version: version,
            sample: sample.key,
          );
        }
      },
      surface: 'entry-json',
      format: 'fixture',
      version: version,
      sample: entity.filename,
    );
  }
}

/// Round-trips the standalone small tables ([category], [extension_meta]).
Future<void> _checkSimpleJsonSurfaces() async {
  Future<void> checkSurface({
    required Directory root,
    required String surface,
    required String itemsKey,
    required FutureOr<Object?> Function(Map<String, dynamic>) parse,
    required Object? Function(Object?) serialize,
  }) async {
    if (!root.existsSync()) return;
    for (final entity in root.listSync()) {
      if (entity is! File || entity.extension != '.json') continue;
      final version = entity.filenameWithoutExtension;
      final doc = jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
      final items = doc[itemsKey] as List<dynamic>;
      for (final (i, item) in items.indexed) {
        await _guarded(
          () async {
            final parsed = await parse((item as Map<String, dynamic>).cast());
            _assertLosslessRoundTrip(
              _normalized(serialize(parsed)),
              _normalized(item),
              surface,
            );
          },
          surface: surface,
          format: '$surface.json',
          version: version,
          sample: 'item-$i',
        );
      }
    }
  }

  await checkSurface(
    root: _categoryFixtures,
    surface: 'category',
    itemsKey: 'items',
    parse:
        (json) => Category.fromJson({
          'name': json['name'],
          'index': json['index'],
          // Mirrors the injection the surreal adapter performs on DB rows.
          'id': metis.DBRecord.fromJson(json['id'] as Map<String, dynamic>),
        }),
    serialize: (parsed) => (parsed! as Category).toJson(),
  );

  await checkSurface(
    root: _extensionMetaFixtures,
    surface: 'extension-meta',
    itemsKey: 'items',
    parse:
        (json) => ExtensionMetaData.fromJson({
          'version': json['version'],
          'enabled': json['enabled'],
          'searchEnabled': json['searchEnabled'],
          // Mirrors the injection the surreal adapter performs on DB rows.
          'id': metis.DBRecord.fromJson(json['id'] as Map<String, dynamic>),
        }),
    serialize: (parsed) => (parsed! as ExtensionMetaData).toDBJson(),
  );
}

/// Replaces `{tb, id}` category record maps with real [metis.DBRecord]s,
/// mirroring how the surreal adapter hydrates record fields before a loader
/// sees them. This routes decoding through the same
/// `Database.getCategoriesbyId` lookup production uses.
Map<String, dynamic> _hydrateRecordMaps(Object? document) {
  final map = Map<String, dynamic>.from(document! as Map<dynamic, dynamic>);
  if (map['categories'] is List) {
    map['categories'] = [
      for (final item in map['categories'] as List)
        if (item is Map && !item.containsKey('name')) metis.DBRecord.fromJson(Map<String, dynamic>.from(item)) else item,
    ];
  }
  return map;
}

/// Asserts that [db] still exposes exactly what the writer seeded.
Future<void> _verifySeededContent(Database db) async {
  final entries = await db.getEntries(0, 100).toList();
  if (entries.length != savedEntrySamples.length) {
    throw StateError(
      'expected ${savedEntrySamples.length} entries, got ${entries.length}',
    );
  }
  for (final sample in savedEntrySamples) {
    final loaded = entries.firstWhere(
      (e) => e.id.uid == sample.id.uid,
      orElse:
          () => throw StateError(
            'entry uid "${sample.id.uid}" missing after read-back',
          ),
    );
    void check(bool ok, String what) {
      if (!ok) {
        throw StateError('${loaded.id.uid}: $what drifted across the round-trip');
      }
    }

    check(loaded.titles?.first == sample.titles?.first, 'title');
    check(
      loaded.episodedata.length == sample.episodedata.length,
      '${loaded.episodedata.length} episodedata rows != ${sample.episodedata.length}',
    );
    check(
      loaded.extensionSettings.length == sample.extensionSettings.length,
      '${loaded.extensionSettings.length} extension settings != ${sample.extensionSettings.length}',
    );
    check(
      loaded.savedSettings.reverse.value ==
          sample.savedSettings.reverse.value,
      'savedSettings.reverse',
    );
    check(
      loaded.categories.map((c) => c.name).toSet().toString() ==
          sample.categories.map((c) => c.name).toSet().toString(),
      'categories',
    );
    check(loaded.episode == sample.episode, 'episode index');
  }

  final categories = await db.getCategories();
  final categoryNames = categories.map((c) => c.name).toSet();
  if (!categoryNames.containsAll(_categories.map((c) => c.name))) {
    throw StateError('category names lost: $categoryNames');
  }

  final activities = await db.getActivities(0, 100).toList();
  if (activities.length != activitySamples.length) {
    throw StateError(
      'expected ${activitySamples.length} activities, got ${activities.length}',
    );
  }
  if (activities.whereType<EpisodeActivity>().isEmpty) {
    throw StateError('EpisodeActivity subtype did not survive the read-back');
  }

  for (final meta in extensionMetaSamples) {
    final loaded = await db.adapter.selectDataClass<ExtensionMetaData>(
      constructExtensionDBRecord(meta.id),
    );
    if (loaded == null) {
      throw StateError('ExtensionMetaData "${meta.id}" missing after read-back');
    }
    if (loaded.enabled != meta.enabled ||
        loaded.searchEnabled != meta.searchEnabled) {
      throw StateError('ExtensionMetaData "${meta.id}" flags drifted ($loaded)');
    }
  }
}

/// Post-[applyBackup] assertions: weaker than [_verifySeededContent] because
/// categories resolve by *name* against whatever the restore target holds.
Future<void> _verifyRestoredBackup(Database db) async {
  final entries = await db.getEntries(0, 100).toList();
  if (entries.isEmpty) {
    throw StateError('backup applied but no entries were restored');
  }
  final knownCategoryNames = _categories.map((c) => c.name).toSet();
  for (final entry in entries) {
    if (entry.episodedata.isEmpty) {
      throw StateError('${entry.id.uid}: episodedata empty after restore');
    }
    if (entry.boundExtensionId.isEmpty) {
      throw StateError('${entry.id.uid}: boundExtensionId empty after restore');
    }
    for (final category in entry.categories) {
      if (!knownCategoryNames.contains(category.name)) {
        throw StateError('${entry.id.uid}: category "${category.name}" did not resolve against the target db');
      }
    }
  }
}
