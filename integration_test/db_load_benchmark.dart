import 'dart:math';

import 'package:dionysos/data/activity/fake_activity.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/library/library_query.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/service/image_store.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:metis/adapter/json_diff.dart' show deepCopyJson;
import 'package:metis/metis.dart'
    show AdapterSurrealDB, CrdtAdapter, Options;

import 'utils/bench.dart';
import 'utils/bench_seed.dart';
import 'utils/screenshot_harness.dart';

/// On-disk (SurrealKV) load benchmark.
///
/// Unlike db_benchmark.dart (in-memory engine), this seeds a real on-disk
/// database in a temp directory, closes it, and re-opens it repeatedly to
/// measure what the app pays on every launch: opening the datastore, the
/// schema/adapter setup in Database.init, and the first library queries on
/// a cold engine and a cold identity cache. It also splits a page load into
/// engine time vs. Dart-side hydration.
///
/// ```bash
/// flutter test integration_test/db_load_benchmark.dart -d windows \
///   --dart-define=BENCH_ENTRIES=2000 --dart-define=BENCH_REOPEN_ITERS=8
/// ```
const _entryCount = int.fromEnvironment('BENCH_ENTRIES', defaultValue: 1000);
const _reopenIters = int.fromEnvironment('BENCH_REOPEN_ITERS', defaultValue: 5);
const _iters = int.fromEnvironment('BENCH_ITERS', defaultValue: 10);
const _writeIters = int.fromEnvironment('BENCH_WRITE_ITERS', defaultValue: 10);

Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final samples = <BenchSample>[];
  final phaseSamples = <String, List<int>>{};

  void addPhase(String name, Duration d) =>
      (phaseSamples[name] ??= []).add(d.inMicroseconds);

  Future<Database> open() async {
    final db = Database();
    await db.init();
    register<Database>(db);
    return db;
  }

  testWidgets('seed on-disk library', (tester) async {
    await bootstrapScreenshots();
    final db = await open();
    final sw = Stopwatch()..start();
    await seedBenchLibrary(db, entryCount: _entryCount);
    await generateFakeActivity(random: Random(4242));
    sw.stop();
    logger.i(
      'Seeded ${await db.getNumEntries()} on-disk entries + activity in '
      '${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s '
      '(BENCH_ENTRIES=$_entryCount)',
    );
    expect(await db.getNumEntries(), _entryCount);
    await db.db.dispose();
  });

  testWidgets('cold launch', (tester) async {
    for (var i = 0; i < _reopenIters; i++) {
      final total = Stopwatch()..start();
      var sw = Stopwatch()..start();
      final db = await open();
      addPhase('launch_db_init', sw.elapsed);
      for (final MapEntry(:key, :value) in db.initTimings.entries) {
        addPhase('  init.$key', value);
      }

      // What the library screen does on first build: categories, a count per
      // visible tab, then the first page of the initially selected tab.
      sw = Stopwatch()..start();
      final categories = await db.getCategories();
      addPhase('launch_categories', sw.elapsed);

      sw = Stopwatch()..start();
      await db.countEntriesByScope(<EntryScope>[
        for (final c in categories) EntryScopeCategory(c),
        const EntryScopeAll(),
        const EntryScopeUncategorized(),
      ]);
      addPhase('launch_tab_counts', sw.elapsed);

      sw = Stopwatch()..start();
      final first = await db
          .queryEntries(scope: EntryScopeCategory(categories.first), page: 0)
          .toList();
      addPhase('launch_first_page', sw.elapsed);
      expect(first, isNotEmpty);
      total.stop();
      addPhase('launch_to_first_page', total.elapsed);

      // Background whole-library scans started at launch (image store
      // prune, download filter, auto-add rules).
      sw = Stopwatch()..start();
      final scanned = await db.getAllEntries().length;
      addPhase('launch_full_scan', sw.elapsed);
      expect(scanned, _entryCount);
      sw = Stopwatch()..start();
      await db.getEntryImageUrls();
      addPhase('launch_image_prune_scan', sw.elapsed);
      sw = Stopwatch()..start();
      await db.getEntryKeys();
      addPhase('launch_download_filter_scan', sw.elapsed);

      await db.db.dispose();
    }
  });

  testWidgets('A/B: previous vs current read paths', (tester) async {
    // Interleaved per iteration so machine noise hits both sides equally;
    // separate runs drift too much to compare. "old" reproduces the query
    // shapes the app used before (FETCH categories, one count per tab,
    // offset-paged full hydration for every scan).
    final db = await open();
    final categories = await db.getCategories();
    final cat = categories.first;
    final scopes = <EntryScope>[
      for (final c in categories) EntryScopeCategory(c),
      const EntryScopeAll(),
      const EntryScopeUncategorized(),
    ];

    Stream<EntrySaved> oldQuery(String sql, Map<String, dynamic> vars) =>
        db.adapter.queryDataClasses<EntrySaved>(query: sql, vars: vars);

    Future<List<EntrySaved>> oldScan() async {
      final all = <EntrySaved>[];
      for (var page = 0; ; page++) {
        final batch = await oldQuery(
          'SELECT * FROM entry ORDER BY id LIMIT 100 START \$o FETCH categories',
          {'o': page * 100},
        ).toList();
        if (batch.isEmpty) break;
        all.addAll(batch);
      }
      return all;
    }

    Future<int> oldCount(String where, [Map<String, dynamic>? vars]) async {
      final [rows as List] = await db.db.query(
        'SELECT count() FROM entry $where GROUP ALL',
        vars: vars,
      );
      return rows.isEmpty ? 0 : rows.first['count'] as int;
    }

    final cases = <String, (Future<Object?> Function(), Future<Object?> Function())>{
      'ab_page25_all': (
        () => oldQuery(
          'SELECT * FROM entry ORDER BY id LIMIT 25 FETCH categories',
          {},
        ).toList(),
        () => db.queryEntries(page: 0).toList(),
      ),
      'ab_page25_category': (
        () => oldQuery(
          'SELECT * FROM entry WHERE categories CONTAINS \$c '
          'ORDER BY id LIMIT 25 FETCH categories',
          {'c': cat.id},
        ).toList(),
        () => db.queryEntries(scope: EntryScopeCategory(cat), page: 0).toList(),
      ),
      'ab_page25_uncategorized': (
        () => oldQuery(
          'SELECT * FROM entry WHERE count(categories) = 0 '
          'ORDER BY id LIMIT 25 FETCH categories',
          {},
        ).toList(),
        () => db
            .queryEntries(scope: const EntryScopeUncategorized(), page: 0)
            .toList(),
      ),
      'ab_tab_counts': (
        () async => [
          for (final c in categories)
            await oldCount('WHERE categories CONTAINS \$c', {'c': c.id}),
          await oldCount(''),
          await oldCount('WHERE count(categories) = 0'),
        ],
        () => db.countEntriesByScope(scopes),
      ),
      'ab_full_scan': (oldScan, () => db.getAllEntries().toList()),
      'ab_image_prune_scan': (
        () async => [
          for (final e in await oldScan()) ImageStoreService.entryImageUrls(e),
        ],
        db.getEntryImageUrls,
      ),
      'ab_download_filter_scan': (
        () async => [for (final e in await oldScan()) e.id.uid],
        db.getEntryKeys,
      ),
    };

    for (final MapEntry(key: name, value: (oldFn, newFn)) in cases.entries) {
      final times = (<int>[], <int>[]);
      final iters = name.contains('scan') ? 5 : _iters;
      for (var i = 0; i <= iters; i++) {
        for (final (fn, out) in [(oldFn, times.$1), (newFn, times.$2)]) {
          db.adapter.clearCache();
          final sw = Stopwatch()..start();
          await fn();
          // First round is warmup.
          if (i > 0) out.add(sw.elapsedMicroseconds);
        }
      }
      samples
        ..add(_toSample('$name.old', times.$1))
        ..add(_toSample('$name.new', times.$2));
    }
    await db.db.dispose();
  });

  testWidgets('bare connect', (tester) async {
    final path =
        'surrealkv://${locate<DirectoryProvider>().databasepath.absolute.path}';
    for (final (name, opts) in [
      ('connect_plain', null),
      ('connect_upgrade_flag', const Options(experimentalUpgradeFrom3X: true)),
    ]) {
      samples.add(
        await bench(name, 5, () async {
          final conn = await AdapterSurrealDB.connect(path, opts: opts);
          await conn.dispose();
        }),
      );
    }
  });

  testWidgets('hydration breakdown', (tester) async {
    final db = await open();
    const pageSql =
        'SELECT * FROM entry ORDER BY id LIMIT 100 FETCH categories';

    Future<List<Map<String, dynamic>>> rawPage() async {
      final [rows as List] = await db.db.query(pageSql);
      return [for (final r in rows) Map<String, dynamic>.from(r as Map)];
    }

    final raw = await rawPage();
    expect(raw.length, 100);
    final hydrated = await Future.wait(raw.map(EntrySaved.fromJson));

    samples.add(await bench('page100_engine_only_fetch', _iters, rawPage));
    samples.add(
      await bench(
        'page100_engine_only_nofetch',
        _iters,
        () => db.db.query('SELECT * FROM entry ORDER BY id LIMIT 100'),
      ),
    );
    samples.add(
      await bench('page100_fromJson_only', _iters, () async {
        for (final row in raw) {
          await EntrySaved.fromJson(row);
        }
      }),
    );
    samples.add(
      await bench('page100_baseline_snapshot', _iters, () async {
        for (final e in hydrated) {
          deepCopyJson(Map<String, dynamic>.from(e.toJson())..remove('id'));
        }
      }),
    );
    samples.add(
      await bench(
        'page100_hydrate_cold',
        _iters,
        () => db.getEntries(0, 100).toList(),
        setup: () async => db.adapter.clearCache(),
      ),
    );
    final keepAlive = await db.getEntries(0, 100).toList();
    samples.add(
      await bench(
        'page100_hydrate_cached',
        _iters,
        () => db.getEntries(0, 100).toList(),
      ),
    );
    expect(keepAlive, isNotEmpty);

    samples.add(
      await bench(
        'full_scan_cold',
        3,
        () => db.getAllEntries().toList(),
        setup: () async => db.adapter.clearCache(),
      ),
    );
    samples.add(
      await bench('page_deep_offset', _iters, () async {
        await db.getEntries(_entryCount ~/ 100 - 1, 100).toList();
      }, setup: () async => db.adapter.clearCache()),
    );
    await db.db.dispose();
  });

  testWidgets('on-disk write path', (tester) async {
    final db = await open();
    final category = (await db.getCategories()).first;
    var seq = 0;
    final added = <EntrySaved>[];
    samples.add(
      await bench('disk_add_entry', _writeIters, () async {
        final e = benchEntry(
          _entryCount + 10000 + seq++,
          categories: [category],
        );
        await db.addEntry(e);
        added.add(e);
      }),
    );
    final target = added.first;
    var ep = 0;
    samples.add(
      await bench('disk_update_episode_finished', _writeIters, () async {
        final uid = target.episodes[ep++ % target.episodes.length].id.uid;
        final data = target.getEpisodeDataById(uid);
        data.finished = !data.finished;
        await db.updateEntry(target);
      }),
    );
    final crdt = db.db.getAdapter<CrdtAdapter>();
    samples.add(
      await crdt.runUnstamped(
        () => bench('disk_update_episode_no_events', _writeIters, () async {
          final uid = target.episodes[ep++ % target.episodes.length].id.uid;
          final data = target.getEpisodeDataById(uid);
          data.finished = !data.finished;
          await db.updateEntry(target);
        }),
      ),
    );
    samples.add(
      await bench(
        'crdt_events_redefine',
        5,
        () => crdt.runUnstamped(() async {}),
      ),
    );
    samples.add(
      await bench(
        'disk_update_unchanged',
        _writeIters,
        () => db.updateEntry(target),
      ),
    );
    samples.add(
      await bench(
        'disk_remove_entry',
        min(_writeIters, added.length - 1),
        () => db.removeEntry(added.removeLast()),
      ),
    );
    await db.db.dispose();
  });

  tearDownAll(() {
    final phases = [
      for (final MapEntry(:key, :value) in phaseSamples.entries)
        _toSample(key, value),
    ];
    logger.i(
      '\nBENCH_ENTRIES=$_entryCount reopen x$_reopenIters'
      '${formatBenchTable([...phases, ...samples])}',
    );
  });
}

BenchSample _toSample(String name, List<int> times) {
  final sorted = [...times]..sort();
  final total = sorted.fold<int>(0, (a, b) => a + b);
  return BenchSample(
    name: name,
    count: sorted.length,
    min: sorted.first,
    max: sorted.last,
    mean: total ~/ sorted.length,
    median: sorted[sorted.length ~/ 2],
    p95: sorted[min(sorted.length - 1, (sorted.length * 0.95).ceil() - 1)],
  );
}
