import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/utils/json_patch.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

Map<String, dynamic> _entryDoc({
  List<String>? genres,
  Map<String, String>? meta,
  List<Map<String, dynamic>>? episodes,
}) {
  return {
    'id': {'uid': 'uid-1', 'iddata': null},
    'url': 'https://example.com',
    'titles': ['Title'],
    'media_type': 'Book',
    'status': 'Releasing',
    'description': 'desc',
    'language': 'en',
    'episodes': episodes ?? [],
    if (genres != null) 'genres': genres,
    if (meta != null) 'meta': meta,
  };
}

rust.EntryDetailed _entry(Map<String, dynamic> doc) =>
    rust.JsonEntryDetailed.fromJson(doc);

void main() {
  group('diffJson/applyJsonPatch', () {
    test('identical documents produce no ops', () {
      final doc = _entryDoc(genres: ['a'], meta: {'k': 'v'});
      expect(diffJson(doc, _entryDoc(genres: ['a'], meta: {'k': 'v'})),
          isEmpty);
    });

    test('round trip: applying the diff to before yields after', () {
      final before = _entryDoc(genres: ['a']);
      final after = _entryDoc(
        genres: ['a', 'b'],
        meta: {'tracker:mediaId': '42', 'weird/key': 'x', 'tilde~key': 'y'},
      );
      after['titles'].add('Alt');
      final patched = applyJsonPatch(
        Map<String, dynamic>.from(before),
        diffJson(before, after),
      );
      expect(patched, after);
    });

    test('meta diff produces per-key ops, not a whole-map replace', () {
      final before = _entryDoc(meta: {'a:one': '1', 'shared': 'x'});
      final after = _entryDoc(meta: {'a:one': '1', 'shared': 'x', 'b:two': '2'});
      final ops = diffJson(before, after);
      expect(ops, hasLength(1));
      expect(ops.single['op'], 'add');
      expect(ops.single['path'], '/meta/b:two');
    });

    test('list changes are one wholesale replace op', () {
      final before = _entryDoc(episodes: [
        {'id': {'uid': 'e1'}, 'name': 'One', 'url': 'u1'},
      ]);
      final after = _entryDoc(episodes: [
        {'id': {'uid': 'e1'}, 'name': 'One', 'url': 'u1'},
        {'id': {'uid': 'e2'}, 'name': 'Two', 'url': 'u2'},
      ]);
      final ops = diffJson(before, after);
      expect(ops, hasLength(1));
      expect(ops.single['op'], 'replace');
      expect(ops.single['path'], '/episodes');
    });

    test('removed keys produce remove ops', () {
      final before = _entryDoc(meta: {'a:one': '1', 'gone': 'x'});
      final after = _entryDoc(meta: {'a:one': '1'});
      final ops = diffJson(before, after);
      expect(ops.single['op'], 'remove');
      expect(ops.single['path'], '/meta/gone');
    });

    test('pointer tokens escape ~ and /', () {
      final before = <String, dynamic>{'meta': <String, dynamic>{}};
      final after = <String, dynamic>{
        'meta': <String, dynamic>{'a/b': '1', 'c~d': '2'},
      };
      final ops = diffJson(before, after);
      expect(
        ops.map((op) => op['path']).toSet(),
        {'/meta/a~1b', '/meta/c~0d'},
      );
      expect(applyJsonPatch(before, ops), after);
    });

    test('sequential patches compose like the old chained fold', () {
      final original = _entryDoc(genres: ['original']);
      // Extension A appends a genre, extension B another one, each working on
      // the doc that already contains A's change.
      final afterA = _entryDoc(genres: ['original', 'a']);
      final docA = _entryDoc(genres: ['original', 'a', 'b']);
      final patchA = diffJson(original, afterA);
      final patchB = diffJson(afterA, docA);

      final folded = applyJsonPatch(
        applyJsonPatch(Map<String, dynamic>.from(original), patchA),
        patchB,
      );
      expect(folded['genres'], ['original', 'a', 'b']);
    });

    test('applying a stale patch throws', () {
      final original = _entryDoc(meta: {'a:one': '1'});
      final target = _entryDoc(meta: {'a:one': '1', 'b:two': '2'});
      final patch = diffJson(original, target);
      // The meta map vanished: the patch can no longer apply.
      final changed = _entryDoc()..remove('meta');
      expect(() => applyJsonPatch(changed, patch), throwsStateError);
    });
  });

  group('EntrySaved serialization', () {
    rust.EntryDetailed savedEntry() => _entry(_entryDoc(
          genres: ['g'],
          meta: {'tracker:mediaId': '1'},
        ));

    test('round trip keeps original, final, generation and patches', () async {
      final saved = EntrySaved(
        entry: _entry(_entryDoc(genres: ['g', 'extra'])),
        original: savedEntry(),
        generation: 3,
        categories: [],
        episodedata: [],
        boundExtensionId: 'ext',
        episode: 0,
        savedSettings: EntrySavedSettings.defaultSettings(),
        extensionSettings: {},
        entryExtensions: [
          EntryExtension(
            extensionId: 'tracker',
            extensionSettings: {},
            patch: [
              {'op': 'add', 'path': '/meta/tracker:mediaId', 'value': '1'},
            ],
            patchGeneration: 3,
          ),
        ],
      );

      final restored = await EntrySaved.fromJson(saved.toJson());

      expect(restored.original.toJson(), saved.original.toJson());
      expect(restored.entry.toJson(), saved.entry.toJson());
      expect(restored.generation, 3);
      final ext = restored.entryExtensions.single;
      expect(ext.patch, saved.entryExtensions.single.patch);
      expect(ext.patchGeneration, 3);
    });

    test('legacy rows without original/generation default sensibly', () async {
      final finalEntry = _entry(_entryDoc(genres: ['g']));
      final legacy = (EntrySaved(
        entry: finalEntry,
        original: finalEntry,
        categories: [],
        episodedata: [],
        boundExtensionId: 'ext',
        episode: 0,
        savedSettings: EntrySavedSettings.defaultSettings(),
        extensionSettings: {},
        entryExtensions: [
          EntryExtension(extensionId: 'tracker', extensionSettings: {}),
        ],
      ).toJson())
        // Simulate a row written before the original/final split.
        ..remove('original')
        ..remove('generation');

      final restored = await EntrySaved.fromJson(legacy);
      expect(restored.original.toJson(), finalEntry.toJson());
      expect(restored.generation, 0);
      expect(restored.entryExtensions.single.patch, isNull);
    });
  });
}
