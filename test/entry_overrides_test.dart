import 'package:dionysos/data/entry/entry_overrides.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

rust.EntryDetailed _entry() => rust.JsonEntryDetailed.fromJson({
  'id': {'uid': 'uid-1', 'iddata': null},
  'url': 'https://example.com',
  'titles': ['Source Title', 'Alt Title'],
  'author': ['Source Author'],
  'media_type': 'Book',
  'status': 'Releasing',
  'description': 'source description',
  'language': 'en',
  'cover': {'url': 'https://example.com/cover.png'},
  'genres': ['action'],
  'episodes': <dynamic>[],
});

EntrySaved _saved({EntryOverrides overrides = EntryOverrides.none}) {
  final entry = _entry();
  return EntrySaved(
    entry: entry,
    original: entry,
    categories: [],
    episodedata: {},
    boundExtensionId: 'ext',
    episode: 0,
    savedSettings: EntrySavedSettings.defaultSettings(),
    extensionSettings: {},
    overrides: overrides,
  );
}

void main() {
  const overrides = EntryOverrides(
    title: 'My Title',
    author: ['Me'],
    description: 'mine',
    genres: [],
    cover: rust.Link(url: 'https://example.com/mine.png'),
    poster: rust.Link(url: 'file://C:/covers/poster.jpg'),
  );

  test('json round trip keeps every field, including an empty tag list', () {
    expect(EntryOverrides.fromJson(overrides.toJson()), overrides);
  });

  test('empty overrides serialize to null, matching the lww default', () {
    expect(EntryOverrides.none.toJson(), isNull);
    expect(EntryOverrides.fromJson(null), EntryOverrides.none);
  });

  test('title override leads the titles and keeps alternatives', () {
    expect(
      const EntryOverrides(title: 'Alt Title')
          .applyTitles(['Source', 'Alt Title']),
      ['Alt Title', 'Source'],
    );
  });

  test('saved entry shows overrides and falls back to the source', () {
    final saved = _saved(
      overrides: const EntryOverrides(title: 'My Title', genres: []),
    );
    expect(saved.title, 'My Title');
    expect(saved.titles, ['My Title', 'Source Title', 'Alt Title']);
    expect(saved.genres, isEmpty);
    expect(saved.description, 'source description');
    expect(saved.cover?.url, 'https://example.com/cover.png');
    expect(saved.entry.titles.first, 'Source Title');
  });

  test('derived columns follow the overridden title and authors', () {
    final row = _saved(overrides: overrides).toJson();
    expect(row['sort_title'], 'My Title');
    expect(row['search_text'], 'My Title Source Title Alt Title Me');
    expect(_saved().toJson().containsKey('overrides'), isTrue);
    expect(_saved().toJson()['overrides'], isNull);
  });

  test('overrides survive a saved-entry json round trip', () async {
    final restored = await EntrySaved.fromJson(
      _saved(overrides: overrides).toJson(),
    );
    expect(restored.overrides, overrides);
  });
}
